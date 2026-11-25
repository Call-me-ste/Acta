import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/calendar/giorno_richiesto.dart';
import '../../features/calendar/day_axis.dart';
import '../../features/calendar/calendar_warmup.dart';
import '../../features/events/event_provider.dart';
import '../../features/filters/filtro_condiviso.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/todos/todo_windows.dart';
import '../shared/date_math.dart';
import '../shared/filtro_attivo.dart';
import '../shared/motion.dart';
import '../shared/tab_active.dart';
import '../shared/view_push_switcher.dart';
import 'calendar_actions.dart';
import 'calendar_active_filters.dart';
import 'calendar_jumps.dart';
import 'calendar_view_cache.dart';
import 'calendar_view_switcher.dart';
import 'calendar_week_view.dart';
import 'day_section.dart';
import 'item_sheet.dart';
import 'month_view.dart';
import 'switch_probe.dart';
import 'week_picker.dart';

/// Il calendario: vista **mese**, **settimana** o **giorno**, scelte dalla
/// pillola in alto.
///
/// Le tre viste condividono il giorno scelto: passare dall'una all'altra non
/// deve farti perdere il punto in cui eri, ed e' il motivo per cui lo stato sta
/// qui e non dentro una delle viste.
class CalendarPage extends StatefulWidget {
  /// Giorno su cui aprire il calendario. Opzionale: serve ai test per non
  /// dipendere dalla data reale in cui girano.
  const CalendarPage({super.key, this.initialDay});

  final DateTime? initialDay;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  /// Il giorno che si sta **guardando** (la griglia del mese) e quello **scelto**
  /// (il giorno su cui si lavora): si puo' scorrere il mese senza spostare il
  /// giorno scelto.
  late DateTime _focusedDay = widget.initialDay ?? DateTime.now();
  late DateTime _selectedDay = widget.initialDay ?? DateTime.now();

  /// I dati delle tre viste si chiedono **all'apertura**, dopo il primo
  /// fotogramma: cosi' il primo cambio vista non legge il database.
  @override
  void initState() {
    super.initState();
    _giornoRichiesto = giornoRichiestoDi(context)
      ?..addListener(_mostraGiornoRichiesto);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // La richiesta può essere arrivata **prima** che questa pagina esistesse
      // (il widget toccato con l'app su un'altra scheda): si consuma qui.
      _mostraGiornoRichiesto();
      warmUpCalendar(
        events: context.read<EventProvider>(),
        todos: context.read<TodoProvider>(),
        focusedDay: _focusedDay,
        selectedDay: _selectedDay,
        filtro: filtroAttuale(context),
      );
    });

    // Sonda per le misure: vedi `switch_probe.dart`.
    if (const bool.fromEnvironment('switchProbe')) probeViewSwitches(context);
  }

  /// La richiesta di un giorno arrivata dal widget mensile.
  GiornoRichiesto? _giornoRichiesto;

  /// Il giorno chiesto si applica **una volta**: lo stato del calendario resta
  /// quello locale della pagina (`setState` della vista), non uno stato
  /// globale.
  void _mostraGiornoRichiesto() {
    final giorno = _giornoRichiesto?.consuma();
    if (giorno == null || !mounted) return;
    _selectDay(giorno);
  }

  @override
  void dispose() {
    _giornoRichiesto?.removeListener(_mostraGiornoRichiesto);
    super.dispose();
  }

  /// Settimana prima/dopo: le freccette spostano **una settimana**, e si va al
  /// suo lunedi' (richiesta dell'utente). Resta scelto il giorno che si guardava.
  void _shiftWeek(int days) {
    _selectDay(CalendarJumps.piuGiorni(DayAxis.mondayOf(_selectedDay), days));
  }

  void _selectDay(DateTime day) {
    // Il giorno scelto e' una **data**, non un istante: `dateOnly` prende i campi
    // del calendario locale, e cosi' non si finisce sul giorno prima.
    final giorno = dateOnly(day);
    setState(() {
      _selectedDay = giorno;
      _focusedDay = giorno;
    });
  }

  /// Le tre viste, costruite solo quando serve: vedi `CalendarViewCache`.
  final _viste = CalendarViewCache();

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppSettingsController>();
    final (view, _) =
        context.select<AppSettingsController, (CalendarView, TodoInCalendario)>(
      (settings) => (settings.calendarView, settings.todoInCalendario),
    );
    // Il filtro si **ascolta qui** e scende come parametro (come il modo): la sua
    // firma entra nella chiave delle viste, altrimenti quella in memoria non si
    // accorgerebbe del cambio.
    final filtro = filtroAttivo(context);

    return Scaffold(
      // Intestazione vuota: il nome della sezione e' gia' nella barra di
      // navigazione in basso. Resta alta zero, cosi' il contenuto non finisce
      // sotto la status bar e non si perde spazio per un titolo ripetuto.
      appBar: AppBar(toolbarHeight: 0, elevation: 0),
      body: Column(
        children: [
          CalendarViewSwitcher(
            value: view,
            onChanged: settings.setCalendarView,
          ),
          CalendarActiveFilters(filter: filtro),
          Expanded(
            // Il cambio vista è un **push in profondità**: la vista nuova copre
            // quella vecchia dal basso (o dall'alto, risalendo), opaca, e la
            // vecchia recede invece di sparire. Niente dissolvenza: due viste
            // dense mezze trasparenti una sull'altra erano la sovrapposizione
            // segnalata, e la dissolvenza costa una superficie in più per
            // fotogramma. Le tre viste restano vive, quindi tornando si ritrova
            // il punto in cui eri.
            child: AscoltatoriSeAttivo(
              // Chi ascolta i dati e' questo widget, non la pagina: la scheda
              // nascosta non si iscrive, e appena torna in scena si iscrive e
              // si riallinea. Il perche' sta in `tab_active.dart`.
              notifiers: [
                context.read<EventProvider>(),
                context.read<TodoProvider>(),
              ],
              builder: (context) {
                // La generazione dei dati entra nella chiave della memoria delle
                // viste: una vista che non si guardava non si e' ricostruita, e
                // appena torna in scena deve sapere che quello che ha in mano e'
                // vecchio. Si legge **adesso** — non quando il widget e' nato —
                // perche' chi ascolta e' il widget qui sopra.
                final generazione = (
                  context.read<EventProvider>().generazione,
                  context.read<TodoProvider>().generazione,
                );
                return ViewPushSwitcher(
                  index: view.index,
                  animate: animationsOn(context),
                  children: [
                    _buildMonth(settings, generazione, filtro),
                    _buildWeek(settings, generazione, filtro),
                    _buildDay(context, settings, generazione, filtro),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: CalendarActions.perLaPagina(
        view: view,
        selectedDay: _selectedDay,
        focusedDay: _focusedDay,
        now: DateTime.now(),
        onToday: _selectDay,
        onOpenDay: _apriGiorno,
        onNew: () =>
            showItemForm(context, type: ItemType.evento, day: _selectedDay),
      ),
    );
  }

  /// Il mese. Le preferenze arrivano dall'ascolto della **pagina** (che le ha
  /// gia'): il modo entra nella chiave della memoria, l'ascolto no.
  Widget _buildMonth(AppSettingsController settings, Object generazione,
      FiltroCondiviso filtro) {
    final modo = settings.todoInCalendario;

    return _viste.vista(
      CalendarViewCache.mese,
      settings.calendarView == CalendarView.mese,
      (generazione, _focusedDay, _selectedDay, modo, filtro.firma),
      () => MonthView(
        focusedDay: _focusedDay,
        selectedDay: _selectedDay,
        filtro: filtro,
        // Il cambio di mese non tocca il giorno scelto: scorre solo il vetro del
        // calendario. `setState` serve perche' l'intestazione (il titolo
        // cliccabile) deve seguire il mese che si sta guardando.
        onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
        // Dall'elenco di mese/anno: si sposta la griglia, la selezione resta.
        onJumpToMonth: (mese) => setState(
          () => _focusedDay = DateTime(mese.year, mese.month),
        ),
        onDaySelected: _selectDay,
        onOpenDay: _apriGiorno,
        modo: modo,
      ),
    );
  }

  /// Tocco prolungato su un giorno — nel **mese** o nella **settimana**: si apre
  /// quel giorno nella vista giorno (la stessa scorciatoia fa la stessa cosa in
  /// tutte e due le viste).
  void _apriGiorno(DateTime day) {
    _selectDay(day);
    context.read<AppSettingsController>().setCalendarView(CalendarView.giorno);
  }

  /// Il giorno: qui il modo e' **intero**, perche' la vista ne distingue tre
  /// (fascia in fondo, righe in giornata, niente).
  Widget _buildDay(BuildContext context, AppSettingsController settings,
      Object generazione, FiltroCondiviso filtro) {
    final modo = settings.todoInCalendario;

    return _viste.vista(
      CalendarViewCache.giorno,
      settings.calendarView == CalendarView.giorno,
      (generazione, _selectedDay, modo, filtro.firma),
      () {
        // I provider si **leggono**, non si ascoltano (`AscoltatoriSeAttivo` sta
        // nella pagina): un ascolto qui ricostruirebbe la vista a ogni scrittura
        // anche da nascosta, che e' il costo che la memoria esiste per togliere.
        final events = context.read<EventProvider>();
        // Le occorrenze si filtrano **dove si leggono**, per il giorno scelto e
        // per i tre che il pager tiene vivi: una strada sola.
        return DaySection(
          day: _selectedDay,
          filtro: filtro,
          todos: context.read<TodoProvider>().todosForDate(_selectedDay),
          modo: modo,
          occurrencesOf: (giorno) =>
              filtro.filtraEventi(events.occurrencesForDate(giorno)),
          onDaySelected: _selectDay,
          onPreviousDay: () => _shiftDay(-1),
          onNextDay: () => _shiftDay(1),
          onPickMonth: () => unawaited(_scegliSettimana()),
        );
      },
    );
  }

  /// «Vai a …» dal **giorno** e dalla **settimana**: si sceglie la settimana
  /// (l'elenco degli intervalli), non il mese — richiesta dell'utente, e come fa
  /// il calendario di AOSP. Si va al **lunedi'** di quella settimana.
  Future<void> _scegliSettimana() async {
    final lunedi = await showWeekPicker(context, initial: _selectedDay);
    if (lunedi == null || !mounted) return;

    _selectDay(lunedi);
  }

  void _shiftDay(int days) {
    _selectDay(CalendarJumps.piuGiorni(_selectedDay, days));
  }

  /// La settimana (vedi il mese per la chiave e per l'ascolto).
  Widget _buildWeek(AppSettingsController settings, Object generazione,
          FiltroCondiviso filtro) =>
      buildCalendarWeek(
        context: context,
        settings: settings,
        generazione: generazione,
        filtro: filtro,
        selectedDay: _selectedDay,
        viste: _viste,
        onSelectDay: _selectDay,
        onOpenDay: _apriGiorno,
        onPreviousWeek: () => _shiftWeek(-7),
        onNextWeek: () => _shiftWeek(7),
        onPickMonth: () => unawaited(_scegliSettimana()),
      );
}
