import 'package:flutter/material.dart';

import '../../features/calendar/day_axis.dart';
import '../../features/events/domain/event_occurrence.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/domain/todo.dart';
import '../shared/date_math.dart';
import '../shared/motion.dart';
import 'day_timeline.dart';
import 'day_todo_section.dart';
import 'hour_labels.dart';
import 'week_all_day_lane.dart';
import 'week_anchor.dart';
import 'week_day_headers.dart';
import 'week_grid_panel.dart';
import 'week_nav_bar.dart';
import 'week_timeline_cache.dart';

/// La vista settimana: **3,5 giorni visibili** con colonne larghe ~100 dp dove
/// titolo e orario si leggono davvero; gli altri giorni si raggiungono
/// scorrendo in orizzontale.
///
/// Tre scrollabili orizzontali (intestazioni, fascia all-day, griglia) sono
/// **sincronizzati sullo stesso offset**: chi trascina uno, trascina tutti, e
/// le colonne restano allineate alle intestazioni.
///
/// Il cambio di settimana è solo sulle **freccette** in alto: un tap, un salto
/// netto — niente gesti morbidi che si confondono con lo scorrere dei giorni
/// (il problema dei bordi segnalato dall'utente).
class WeekView extends StatefulWidget {
  const WeekView({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.occurrences,
    required this.todos,
    this.now,
    this.onTap,
    this.onDaySelected,
    this.onOpenDay,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPickMonth,
    this.onTodo,
    this.onOpenTodo,
    this.isDone,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final List<EventOccurrence> occurrences;

  /// I todo della settimana, giorno per giorno, e **come** mostrarli (la
  /// preferenza «todo nel calendario»): in un record solo perche' sono la stessa
  /// cosa e perche' questo file ha un tetto di righe.
  ///
  /// «Compatta»: la fascia in fondo col giorno scelto. «Pieni»: i todo nelle
  /// colonne dei giorni (quelli con orario) e nella fascia sopra la griglia
  /// (quelli senza). «Nascosta»: niente.
  final ({Map<DateTime, List<Todo>> perGiorno, TodoInCalendario modo}) todos;

  /// Chiamato dal cerchio di una casella: spunta il todo per quel giorno.
  final void Function(Todo todo, DateTime day)? onTodo;

  /// Chiamato dal tocco sulla casella: apre il form del todo.
  final void Function(Todo todo, DateTime day)? onOpenTodo;

  /// Vero se il todo e' fatto in quel giorno (per un ricorrente e'
  /// l'occorrenza). Arriva da fuori: le viste non leggono i provider.
  final bool Function(Todo todo, DateTime day)? isDone;
  final DateTime? now;
  final ValueChanged<EventOccurrence>? onTap;
  final ValueChanged<DateTime>? onDaySelected;

  /// Tocco **prolungato** su un giorno: si apre quel giorno nella vista giorno
  /// (stessa scorciatoia della vista mese, stessa funzione in `calendar_page`).
  final ValueChanged<DateTime>? onOpenDay;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  /// Scegliere mese e anno dall'intestazione (stessa cosa che fa il mese).
  final VoidCallback onPickMonth;

  /// Tre giorni e mezzo: il mezzo dice che c'è altro da scorrere.
  static const double visibleDays = 3.5;

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  /// La colonna delle ore, fissa a sinistra: scorre in verticale con la griglia
  /// ma non si muove in orizzontale quando si pannano i giorni. La misura sta in
  /// `HourLabels.width`: e' la stessa che usano le intestazioni per indentarsi.
  static const double _gutter = HourLabels.width;

  late final ScrollController _vScroll = ScrollController(
    initialScrollOffset: 7 * DayTimeline.defaultHourHeight,
  );

  final ScrollController _headerPan = ScrollController();
  final ScrollController _lanePan = ScrollController();
  final ScrollController _gridPan = ScrollController();
  bool _following = false;

  /// Il riallineamento orizzontale: vedi `WeekAnchor`, dove stanno i due casi.
  final WeekAnchor _anchor = WeekAnchor();

  /// La griglia ricordata: vedi `WeekTimelineCache`.
  final WeekTimelineCache _timeline = WeekTimelineCache();

  @override
  void initState() {
    super.initState();
    for (final controller in [_headerPan, _lanePan, _gridPan]) {
      controller.addListener(() => _follow(controller));
    }
  }

  @override
  void dispose() {
    _vScroll.dispose();
    _headerPan.dispose();
    _lanePan.dispose();
    _gridPan.dispose();
    super.dispose();
  }

  /// Chi trascina uno dei tre pannelli trascina tutti: l'offset resta condiviso
  /// e le intestazioni non si staccano mai dalle colonne. Il guard serve a non
  /// rimbalzare nella propria notifica.
  void _follow(ScrollController source) {
    if (_following) return;
    _following = true;
    for (final controller in [_headerPan, _lanePan, _gridPan]) {
      if (controller.hasClients && controller.offset != source.offset) {
        controller.jumpTo(source.offset);
      }
    }
    _following = false;
  }

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var i = 0; i < DayAxis.giorniAsseSettimana; i++)
        _addDays(widget.weekStart, i),
    ];
    final allDay = <DateTime, List<EventOccurrence>>{};
    for (final occurrence in widget.occurrences) {
      if (occurrence.event.allDay) {
        allDay.putIfAbsent(occurrence.date, () => []).add(occurrence);
      }
    }

    // In «Pieni» i todo senza orario stanno nella fascia sopra la griglia: nella
    // griglia delle ore non hanno un posto. In «compatta» e «nascosta» la fascia
    // non porta todo (li mostra la striscia in fondo, o nessuno).
    final todoSenzaOrario = widget.todos.modo == TodoInCalendario.pieni
        ? widget.todos.perGiorno.map(
            (day, todos) => MapEntry(
              day,
              [
                for (final todo in todos)
                  if (todo.firstTime == null) todo,
              ],
            ),
          )
        : const <DateTime, List<Todo>>{};
    // Il giorno scelto puo' avere un orario (all'avvio e' `DateTime.now()`): le
    // chiavi della mappa sono **date**, quindi si taglia prima di cercare.
    final scelto = dateOnly(widget.selectedDay);
    final todoDelGiorno = widget.todos.perGiorno[scelto] ?? const <Todo>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Le colonne dei giorni si dividono lo spazio che **resta** dopo la
        // colonna degli orari: con la larghezza intera si vedevano 3,15 giorni
        // invece dei 3,5 voluti (e le date risultavano più larghe delle celle).
        final animazioni = animationsOn(context);
        final columnWidth =
            (constraints.maxWidth - _gutter) / WeekView.visibleDays;
        final columnsWidth = columnWidth * DayAxis.giorniAsseSettimana;

        // Il giorno scelto alla prima colonna, e la settimana nuova che riparte
        // dal lunedì: i due casi stanno in `WeekAnchor`, con il perché.
        _anchor.allinea(
          weekStart: widget.weekStart,
          selectedDay: widget.selectedDay,
          columnWidth: columnWidth,
          pannelli: [_headerPan, _lanePan, _gridPan],
          animate: animazioni,
        );

        return Column(
          children: [
            WeekNavBar(
              weekStart: widget.weekStart,
              onPrevious: widget.onPreviousWeek,
              onNext: widget.onNextWeek,
              onPick: widget.onPickMonth,
            ),
            SizedBox(
              // Altezza derivata da sigla + cerchio + padding, non dalla scala
              // applicata all'intera fascia: a 2.0 non raddoppia.
              height: WeekDayHeaders.height(context),
              child: Row(
                children: [
                  // **La stessa colonna delle ore** che sta sotto: senza,
                  // l'intestazione parteva da x=0 mentre la griglia partiva da
                  // x=40, quindi le date erano sfalsate di 40 px rispetto alle
                  // colonne dei giorni (e la prima finiva sopra l'orario).
                  const SizedBox(width: _gutter),
                  Expanded(
                    child: _panned(
                      controller: _headerPan,
                      child: WeekDayHeaders(
                        days: days,
                        width: columnsWidth,
                        selectedDay: widget.selectedDay,
                        now: widget.now,
                        onDaySelected: widget.onDaySelected,
                        onOpenDay: widget.onOpenDay,
                        animate: animazioni,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (allDay.isNotEmpty ||
                todoSenzaOrario.values.any((todos) => todos.isNotEmpty))
              Row(
                children: [
                  // Anche la striscia dei «tutto il giorno» sta sopra la griglia:
                  // stessa indentazione, stessa larghezza di colonna.
                  const SizedBox(width: _gutter),
                  Expanded(
                    child: _panned(
                      controller: _lanePan,
                      child: WeekAllDayLane(
                        days: days,
                        width: columnsWidth,
                        byDay: allDay,
                        todoByDay: todoSenzaOrario,
                        onTap: widget.onTap,
                        onTodo: widget.onOpenTodo,
                        isDone: widget.isDone,
                      ),
                    ),
                  ),
                ],
              ),
            Expanded(
              child: WeekGridPanel(
                days: days,
                selectedDay: widget.selectedDay,
                columnsWidth: columnsWidth,
                columnWidth: columnWidth,
                occurrences: widget.occurrences,
                todos: widget.todos,
                timeline: _timeline,
                vScroll: _vScroll,
                gridPan: _gridPan,
                now: widget.now,
                onTap: widget.onTap,
                onTodo: widget.onTodo,
                onOpenTodo: widget.onOpenTodo,
                isDone: widget.isDone,
              ),
            ),
            // I todo del giorno scelto, in fondo: la **stessa** fascia del mese
            // e della vista giorno (`DayTodoSection`).
            if (widget.todos.modo == TodoInCalendario.compatta &&
                todoDelGiorno.isNotEmpty)
              DayTodoSection(day: scelto, todos: todoDelGiorno),
          ],
        );
      },
    );
  }

  /// Un pannello orizzontale: largo quanto le **sette** colonne.
  Widget _panned({
    required ScrollController controller,
    required Widget child,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: controller,
      child: child,
    );
  }

  static DateTime _addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);
}

/// Le ore a sinistra della griglia: fisso in orizzontale, scorre in verticale
/// con le colonne.
