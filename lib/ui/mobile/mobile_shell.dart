import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../features/calendar/giorno_richiesto.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/todo_filter.dart';
import '../../features/todos/todo_filter_controller.dart';
import '../../features/notes/note_selection.dart';
import '../../features/todos/todo_selection.dart';
import '../../features/updates/update_controller.dart';
import '../shared/motion.dart';
import '../shared/tab_active.dart';
import '../shared/view_push_switcher.dart';
import 'agenda_page.dart';
import 'bottom_bar.dart';
import 'calendar_page.dart';
import 'notes_page.dart';
import 'overdue_sheet.dart';
import 'settings_page.dart';
import 'todo_page.dart';
import 'update_banner.dart';

/// Guscio mobile: barra di navigazione in basso con le sezioni dell'app.
///
/// Le pagine si costruiscono alla prima visita e conservano lo stato.
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _currentIndex = BottomBar.centrale;

  /// La richiesta di conferma si fa **una volta per sessione**: «No» non scrive
  /// niente, quindi senza questo flag tornerebbe a ogni ricostruzione.
  bool _overdueAsked = false;

  /// Vero mentre il foglio degli scaduti è in scena: un tocco da widget su un
  /// giorno deve chiuderlo, non lasciarlo sopra il calendario.
  bool _overdueOpen = false;

  /// La storia delle posizioni visitate, per il tasto indietro: **scheda attiva e
  /// vista del calendario**. Il tetto e' basso di proposito — il tasto indietro
  /// serve a tornare indietro di poco, non a ripercorrere la sessione.
  static const int _maxStoria = 20;
  final List<({int scheda, CalendarView vista})> _storia = [];

  /// L'ultima vista del calendario vista da qui: serve ad accorgersi del cambio,
  /// perche' la vista si cambia dalle preferenze (pillola, tasti, gesti).
  CalendarView? _vistaVista;

  /// Vero fra il primo indietro e la scadenza: il secondo indietro chiude.
  bool _uscitaArmata = false;
  Timer? _riposo;

  /// Le preferenze a cui siamo iscritti: serve per **togliere** il listener
  /// quando lo scheletro se ne va (senza, resterebbe appeso per sempre).
  AppSettingsController? _settings;

  /// La richiesta di un giorno arrivata dal widget mensile: si ascolta qui
  /// perché la scheda del calendario può non essere ancora stata costruita, e
  /// va portata in scena **prima** che possa consumarla.
  GiornoRichiesto? _giornoRichiesto;

  @override
  void initState() {
    super.initState();
    // Il cambio di vista del calendario passa dalle preferenze: lo si osserva da
    // qui per poterlo mettere in storia.
    final settings = context.read<AppSettingsController>();
    _settings = settings;
    _vistaVista = settings.calendarView;
    settings.addListener(_vistaCambiata);
    _giornoRichiesto = giornoRichiestoDi(context)
      ?..addListener(_mostraGiornoRichiesto);
    // Dopo il primo frame: serve un contesto con i provider già montati. Se
    // l'app è stata aperta da un widget, `main` ha già messo il giorno in
    // `GiornoRichiesto`: `_askOverdue` lo vede e non apre il foglio.
    WidgetsBinding.instance.addPostFrameCallback((_) => _askOverdue());
  }

  /// Un tocco su un giorno del widget mensile: si va sulla scheda Calendario.
  /// Il **giorno** lo applica la pagina, che consuma la richiesta (qui si sa
  /// solo che si sta guardando il calendario).
  void _mostraGiornoRichiesto() {
    if (!mounted || _giornoRichiesto?.giorno == null) return;
    if (_overdueOpen) {
      _overdueOpen = false;
      Navigator.of(context).maybePop();
    }
    if (_currentIndex == BottomBar.centrale) return;
    setState(() {
      _currentIndex = BottomBar.centrale;
    });
  }

  @override
  void dispose() {
    _riposo?.cancel();
    _settings?.removeListener(_vistaCambiata);
    _giornoRichiesto?.removeListener(_mostraGiornoRichiesto);
    super.dispose();
  }

  void _vistaCambiata() {
    if (!mounted) return;
    final vista = context.read<AppSettingsController>().calendarView;
    if (vista == _vistaVista) return;
    // Si ricorda la posizione **di prima**: la nuova vista e' gia' attiva.
    final precedente = _vistaVista;
    _vistaVista = vista;
    if (precedente != null) {
      _ricorda(scheda: _currentIndex, vista: precedente);
    }
  }

  void _ricorda({required int scheda, required CalendarView vista}) {
    final posizione = (scheda: scheda, vista: vista);
    if (_storia.isNotEmpty && _storia.last == posizione) return;
    _storia.add(posizione);
    if (_storia.length > _maxStoria) _storia.removeAt(0);
  }

  /// L'indice della scheda Todo in [_pages] (Note, **Todo**, Calendario,
  /// Agenda, Impostazioni).
  static const int _schedaTodo = 1;

  /// Si entra nella scheda Todo **sempre da «Oggi»**: la vista dei todo e' una
  /// lente su cosa fare adesso, non una posizione da ritrovare — e chi apre
  /// quella scheda sta cercando quello. I filtri fini (categorie, priorita')
  /// restano quelli scelti: sono un vincolo, non un punto di vista.
  void _tornaSuOggi(int index) {
    if (index != _schedaTodo) return;
    context.read<TodoFilterController>().setRange(TodoRange.oggi);
  }

  /// Il tasto indietro: prima la posizione di prima, poi l'avviso, e solo il
  /// secondo tocco ravvicinato chiude l'app.
  ///
  /// Perche' un avviso invece di chiudere subito: il calendario si tocca tutto il
  /// giorno, e un indietro per sbaglio che chiude l'app fa perdere il punto in cui
  /// eri. Perche' solo due secondi: chi vuole uscire lo dice due volte, e chi ha
  /// sbagliato non si trova un avviso appiccicato per sempre.
  void _indietro() {
    // Prima di tutto: se c'e' una selezione aperta (i todo della scheda Todo), il
    // tasto indietro chiude **quella** — non cambia scheda e non esce dall'app.
    // Si puo' fare qui perche' la selezione sta in un controller, sopra il guscio,
    // e non nello stato della pagina: `ModalRoute` chiama l'`onPopInvoked` di
    // **tutti** i `PopScope` registrati, quindi uno dentro la pagina non basta.
    final selezioneNote = context.read<SelezioneDelleNote>();
    if (selezioneNote.attiva) {
      selezioneNote.chiudi();
      return;
    }

    final selezione = context.read<SelezioneDeiTodo>();
    if (selezione.attiva) {
      selezione.chiudi();
      return;
    }

    if (_storia.isNotEmpty) {
      final posizione = _storia.removeLast();
      context.read<AppSettingsController>().setCalendarView(posizione.vista);
      _tornaSuOggi(posizione.scheda);
      setState(() {
        _currentIndex = posizione.scheda;
      });
      return;
    }

    if (_uscitaArmata) {
      _riposo?.cancel();
      SystemNavigator.pop();
      return;
    }

    setState(() => _uscitaArmata = true);
    _riposo?.cancel();
    _riposo = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _uscitaArmata = false);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Premi di nuovo per uscire'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  /// Gli scaduti sono consultabili all'avvio senza coprire il calendario.
  void _askOverdue() {
    if (_overdueAsked || !mounted) return;
    _overdueAsked = true;
    // Se l'app è stata aperta da un widget su un giorno, il calendario deve
    // arrivare subito su quel giorno: il foglio degli scaduti lo coprirebbe.
    if (_giornoRichiesto?.giorno != null) return;

    final items = scadutiDaConfermare(context);
    if (items.isEmpty) return;
    final eventi = items.where((item) => item.isEvent).length;
    final todos = items.length - eventi;
    final riepilogo = [
      if (eventi > 0) eventi == 1 ? '1 evento' : '$eventi eventi',
      if (todos > 0) '$todos To do',
    ].join(' · ');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Da confermare: $riepilogo'),
      duration: const Duration(seconds: 8),
      persist: false,
      action: SnackBarAction(
        label: 'Vedi',
        onPressed: () {
          final aggiornati = scadutiDaConfermare(context);
          if (aggiornati.isEmpty) return;
          _overdueOpen = true;
          unawaited(showOverdueSheet(context, aggiornati).whenComplete(() {
            _overdueOpen = false;
          }));
        },
      ),
    ));
  }

  /// Le pagine nello stesso ordine di `BottomBar.voci` e della cronologia.
  static const _pages = [
    NotesPage(),
    TodoPage(),
    CalendarPage(),
    AgendaPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final updates = context.read<UpdateController?>();
    return PopScope(
      // Il pop lo gestiamo noi: vedi `_indietro`.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _indietro();
      },
      child: Scaffold(
        body: Column(
          children: [
            if (updates != null) UpdateBanner(controller: updates),
            Expanded(
              child: ViewPushSwitcher(
                index: _currentIndex,
                animate: animationsOn(context),
                warmUp: false,
                children: [
                  for (final (index, page) in _pages.indexed)
                    TabActive(attivo: index == _currentIndex, child: page),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomBar(
          index: _currentIndex,
          onSelected: (index) => setState(() {
            // La posizione che si lascia va in storia: e' quella a cui torna
            // l'indietro.
            if (index != _currentIndex) {
              _ricorda(
                scheda: _currentIndex,
                vista: context.read<AppSettingsController>().calendarView,
              );
            }
            _tornaSuOggi(index);
            _currentIndex = index;
          }),
        ),
      ),
    );
  }
}
