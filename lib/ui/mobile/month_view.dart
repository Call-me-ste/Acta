import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/calendar/month_grid_geometry.dart';
import '../../features/events/event_provider.dart';
import '../../features/filters/filtro_condiviso.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/todo_provider.dart';
import '../../theme/design_tokens.dart';
import '../shared/date_math.dart';
import '../shared/empty_state.dart';
import '../shared/motion.dart';
import '../shared/scroll_to_top_on_change.dart';
import 'event_tile.dart';
import 'item_detail_sheet.dart';
import 'month_cache.dart';
import 'month_grid_painter.dart';
import 'month_grid.dart';
import 'month_grid_cells.dart';
import 'month_header.dart';
import 'month_pager.dart';
import 'month_preload.dart';
import 'month_window_cache.dart';
import 'day_todo_section.dart';
import 'month_year_picker.dart';

/// La vista mese, disegnata come le agende di iOS: il numero del giorno
/// centrato in alto e sotto fino a **tre barre sottili** colorate, una per
/// evento — niente puntini accatastati né chip sovrapposti al numero.
///
/// I todo diventano un **badge** con il conteggio nell'angolo alto a destra
/// della cella, come i badge iOS. I giorni fuori mese restano un numero
/// attenuato senza barre: la griglia pulisce da sola.
///
/// La griglia è **nostra** (`MonthGrid`): un disegno per pagina invece di 42
/// celle da una ventina di widget (celle, tocco e scorrimento sono in
/// `month_grid.dart`, `month_grid_painter.dart` e `month_pager.dart`).
class MonthView extends StatefulWidget {
  const MonthView({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onJumpToMonth,
    required this.onOpenDay,
    required this.modo,
    required this.filtro,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  /// Porta la griglia su un mese scelto dall'elenco (titolo cliccabile). Il giorno
  /// **scelto** non cambia: si sposta il vetro del calendario, non la selezione.
  final ValueChanged<DateTime> onJumpToMonth;

  /// Tocco prolungato su un giorno: si apre quel giorno nella vista giorno.
  final ValueChanged<DateTime> onOpenDay;

  /// Come si vedono i todo: **compatta** la fascia in fondo, **piena** solo i
  /// pallini (i todo stanno nella giornata), **nascosta** niente — il modo intero,
  /// perche' gli stati sono tre. Arriva come **parametro** (un ascolto qui dentro
  /// ricostruirebbe la vista a ogni cambio di preferenza: vedi `CalendarViewCache`).
  final TodoInCalendario modo;

  /// Il filtro condiviso: taglia eventi e todo **all'origine** (la finestra nasce
  /// gia' filtrata e la firma lo comprende), e arriva come parametro per lo stesso
  /// motivo di [modo].
  final FiltroCondiviso filtro;

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  /// Il controller tiene la posizione: tornando al mese dopo un giro in
  /// settimana o giorno, la pagina è dove l'avevi lasciata.
  final ScrollController _scroll = ScrollController();

  /// Altezza approssimata di una riga evento: serve a togliere il margine quando
  /// gli eventi riempiono già lo schermo.
  static const double _eventRowHeight = 76;

  /// Il «torna in cima» quando cambia il giorno: vedi `ScrollToTopOnChange`.
  late final ScrollToTopOnChange _inCima = ScrollToTopOnChange(_scroll);

  /// Il precaricamento dei mesi vicini: una coda con la sua memoria, un mese per
  /// fotogramma (vedi `month_preload.dart`).
  late final PrecaricoDeiMesi _precarico = PrecaricoDeiMesi(scalda: _scalda);

  /// Le finestre dei mesi già calcolate: senza memoria uno scorrimento ne faceva
  /// nove per fotogramma (vedi `month_window_cache.dart`).
  final FinestreDeiMesi _finestre = FinestreDeiMesi();

  /// La memoria delle celle, per mese: le prepara il precaricamento, cosi' la
  /// pagina che entra non misura 42 testi dentro il fotogramma del dito.
  final CachePerMese<List<GiornoPronto>> _celle = CachePerMese();

  @override
  void initState() {
    super.initState();
    _precarico.programma(widget.focusedDay);
  }

  @override
  void didUpdateWidget(MonthView vecchio) {
    super.didUpdateWidget(vecchio);
    if (vecchio.focusedDay.year != widget.focusedDay.year ||
        vecchio.focusedDay.month != widget.focusedDay.month) {
      _precarico.programma(widget.focusedDay);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// La finestra di un mese (quella di prima se dati, giorno scelto e filtro non
  /// sono cambiati) **e le sue celle**: la strada sta in `month_preload.dart`.
  void _scalda(DateTime mese) {
    if (!mounted) return;
    scaldaIlMese(
      context,
      mese: mese,
      celle: _celle,
      selezione: widget.selectedDay,
      finestre: _finestre,
      filtro: widget.filtro,
    );
  }

  /// Tocco su un giorno: la selezione cambia solo se il giorno è un altro.
  void _seleziona(DateTime giorno) {
    if (dateOnly(giorno) == dateOnly(widget.selectedDay)) return;
    widget.onDaySelected(giorno);
  }

  @override
  Widget build(BuildContext context) {
    final focusedDay = widget.focusedDay;
    final selectedDay = widget.selectedDay;
    final animazioni = animationsOn(context);

    // Cambiando giorno o mese, la griglia torna in cima (la regola sta in
    // `ScrollToTopOnChange`): le celle di quel giorno si devono vedere per intero.
    _inCima.aggiorna(
      selectedDay: selectedDay,
      focusedDay: focusedDay,
      animate: animazioni,
    );

    // Le due sorgenti dei dati della griglia si **leggono**, non si ascoltano:
    // l'ascolto (e la chiave di questa vista) sta nella pagina.
    final eventProvider = context.read<EventProvider>();
    final todoProvider = context.read<TodoProvider>();
    final finestra = _finestre.di(
      mese: focusedDay,
      eventi: eventProvider,
      todo: todoProvider,
      selezione: selectedDay,
      filtro: widget.filtro,
    );
    final todos = finestra.todosOfSelectedDay;
    final occurrences = finestra.occurrencesOfSelectedDay;

    // La riga deriva dal contenuto: a 2.0 non deve raddoppiare.
    final cellWidth =
        MediaQuery.sizeOf(context).width / MonthGridGeometry.colonne;
    final misure = MisureMese.di(context, cellWidth: cellWidth);
    final altezzaGriglia = MonthGridGeometry(
      month: focusedDay,
      cellWidth: cellWidth,
      rowHeight: misure.rowHeight,
      headerHeight: misure.headerHeight,
    ).altezza;

    // Con pochi eventi il mese non si poteva tirare via (non c'era niente da
    // scorrere): il margine finale gli dà una corsa pari alla griglia.
    final spacer = altezzaGriglia - occurrences.length * _eventRowHeight;

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(
          child: MonthHeader(
            focusedDay: focusedDay,
            onPrevious: () => widget.onJumpToMonth(
              DateTime(focusedDay.year, focusedDay.month - 1),
            ),
            onNext: () => widget.onJumpToMonth(
              DateTime(focusedDay.year, focusedDay.month + 1),
            ),
            onPick: () async {
              final scelto = await showMonthYearPicker(
                context,
                initial: focusedDay,
              );
              if (scelto != null) widget.onJumpToMonth(scelto);
            },
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: altezzaGriglia,
            child: MonthPager(
              month: focusedDay,
              animate: animazioni,
              onMonthChanged: widget.onPageChanged,
              // L'altezza dipende dal mese: 35 giorni (cinque righe) o 42 (sei).
              altezzaDelMese: (mese) => MonthGridGeometry(
                month: mese,
                cellWidth: 0,
                rowHeight: misure.rowHeight,
                headerHeight: misure.headerHeight,
              ).altezza,
              itemBuilder: (context, mese) {
                // **Una volta sola** per mese: prima se ne facevano due (una per
                // `eventsByDay` e una per `todoCounts`), e con cinque pagine
                // pronte erano nove finestre per fotogramma di scorrimento.
                final dati = _finestre.di(
                  mese: mese,
                  eventi: eventProvider,
                  todo: todoProvider,
                  selezione: selectedDay,
                  filtro: widget.filtro,
                );
                return MonthGrid(
                  // La chiave è **il mese**: la pagina che entra esiste già (i due
                  // mesi per lato si costruiscono prima) e non viene rifatta
                  // mentre il dito è ancora giù.
                  key: ValueKey('mese-${mese.year}-${mese.month}'),
                  month: mese,
                  selectedDay: selectedDay,
                  today: DateTime.now(),
                  eventsByDay: dati.eventsByDay,
                  todoCounts: dati.todoCounts,
                  conTodo: widget.modo != TodoInCalendario.nascosta,
                  filtroFirma: widget.filtro.firma,
                  generazione: (
                    eventProvider.generazione,
                    todoProvider.generazione,
                  ),
                  celle: _celle,
                  animate: animazioni,
                  rowHeight: misure.rowHeight,
                  headerHeight: misure.headerHeight,
                  onDaySelected: _seleziona,
                  onOpenDay: widget.onOpenDay,
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        if (todos.isNotEmpty && widget.modo == TodoInCalendario.compatta)
          SliverToBoxAdapter(
            child: DayTodoSection(day: selectedDay, todos: todos),
          ),
        if (occurrences.isEmpty)
          // Altezza fissa e **non** `SliverFillRemaining`: quello chiede le
          // dimensioni intrinseche, che il `LayoutBuilder` dello stato vuoto
          // non sa dare (serve a centrare quando lo spazio basta).
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: EmptyState(
                icon: Icons.event_busy_outlined,
                message: 'Nessun evento in questo giorno',
              ),
            ),
          )
        else
          // Lazy: di un giorno con trenta eventi se ne costruiscono solo
          // quelli che si vedono.
          SliverList.builder(
            itemCount: occurrences.length,
            itemBuilder: (context, index) => EventTile(
              occurrence: occurrences[index],
              onTap: () => showItemDetail(
                context,
                event: occurrences[index].event,
                day: selectedDay,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: spacer > 0 ? spacer : 0),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.calendarActionsClearance),
        ),
      ],
    );
  }
}
