import 'dart:async';

import '../../core/database/database_service.dart';
import '../events/domain/event.dart';
import '../events/domain/event_occurrence.dart';
import '../events/domain/event_series.dart';
import '../todos/domain/todo.dart';
import 'domain/reminder_plan.dart';
import 'domain/reminder_planner.dart';
import 'domain/riepilogo_planner.dart';
import 'notification_channels.dart';
import 'notification_actions.dart';
import 'notification_settings_controller.dart';
import 'notification_sink.dart';

/// Chi tiene **allineati** gli avvisi del sistema con quelli che ci devono
/// essere adesso.
///
/// Il mestiere è la **riconciliazione**, e la verità sta in Android: si chiede
/// l'elenco di quello che il sistema ha (`sink.pianificati()`), si calcola quello
/// che ci deve essere (`planReminders`), si annulla chi avanza e si pianifica chi
/// manca. Chi c'è già **non si tocca** — è così che una modifica non fa
/// sparire-e-riapparire gli avvisi degli altri, e che un riavvio non duplica
/// niente. Non c'è nessuna tabella nostra da tenere allineata: si disallineerebbe
/// al primo riavvio, questa no.
///
/// Legge dal **database**, non dai provider: gira anche all'avvio e dopo un
/// riavvio del telefono, quando nessuna schermata esiste ancora.
class NotificationScheduler {
  NotificationScheduler(
    this._db,
    this._notifiche,
    this._sink, {
    DateTime Function()? adesso,
    this.debounce = const Duration(seconds: 2),
  }) : _adesso = adesso ?? DateTime.now;

  final DatabaseService _db;
  final NotificationSettingsController _notifiche;
  final NotificationSink _sink;
  final DateTime Function() _adesso;

  /// Quanto si aspetta prima di ricalcolare: due scritture di fila (una modifica
  /// e una spunta) fanno **un giro solo**. Il pianificatore è puro e veloce, ma
  /// ogni giro parla col sistema operativo.
  final Duration debounce;

  /// La finestra entro cui si **materializzano** gli avvisi: oltre si ricalcola
  /// quando l'app torna in primo piano (la finestra vera, 30 giorni, sta in
  /// `ReminderInputs`). Qui si chiedono un giorno in più di occorrenze, perché un
  /// evento appena fuori finestra con un anticipo lungo ha il suo avviso dentro.
  static const Duration _occorrenzeOltreLaFinestra = Duration(days: 31);

  /// Quanto indietro si guarda per dire se c'è **qualcosa da confermare**: è la
  /// stessa finestra del foglio degli scaduti all'apertura.
  static const Duration _scadutiIndietro = Duration(days: 30);

  Timer? _timer;
  bool _inCorso = false;
  bool _ancora = false;

  /// **Allinea** adesso: una riconciliazione completa.
  Future<void> riconcilia() async {
    // Se un giro è in corso non se ne avvia un secondo (si accavallerebbero due
    // letture di quello che Android ha): si segna che serve rifarlo, e il giro
    // in corso lo rifà prima di uscire.
    if (_inCorso) {
      _ancora = true;
      return;
    }
    _inCorso = true;
    try {
      do {
        _ancora = false;
        await _giro();
      } while (_ancora);
    } finally {
      _inCorso = false;
    }
  }

  /// Chiede una riconciliazione **fra poco** (non subito): è quello che si chiama
  /// dopo ogni modifica di evento, todo o impostazioni.
  void programma() {
    _timer?.cancel();
    _timer = Timer(debounce, riconcilia);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Quanti avvisi risultano pianificati adesso: lo legge la riga di stato in
  /// Impostazioni (e i test).
  Future<int> quanti() async => (await _sink.pianificati()).length;

  // ─── Interni ──────────────────────────────────────────

  Future<void> _giro() async {
    await _sink.prepara();

    final voluti = _piano();
    final attuali = await _sink.pianificati();

    for (final id in attuali.keys.toSet().difference(voluti.keys.toSet())) {
      if (idDiRinvio(id) &&
          NotificationActions(_db)
              .rinvii(_adesso(), _notifiche)
              .any((avviso) => avviso.id == id)) {
        continue;
      }
      await _sink.annulla(id);
    }
    for (final voce in voluti.entries) {
      // Non basta l'id: un evento **spostato** tiene lo stesso id (l'id è
      // stabile per elemento, giorno e anticipo) ma deve suonare a un'ora
      // diversa, e un'impostazione cambiata deve usare un **canale** diverso. Il
      // carico porta dentro tutti e due, quindi id e carico insieme dicono se
      // quello che il sistema ha è ancora quello che ci deve essere.
      if (attuali[voce.key] == caricoAvviso(voce.value, _notifiche)) continue;
      if (idDiRinvio(voce.key) && !voce.value.when.isAfter(_adesso())) continue;
      await _sink.pianifica(voce.value, _notifiche);
    }
  }

  /// **Il piano**: gli id degli avvisi che ci devono essere, con il loro
  /// contenuto. Un tipo spento non entra nel piano (non si filtra dopo: non
  /// viene proprio calcolato).
  Map<int, ScheduledReminder> _piano() {
    // Interruttore generale spento: il piano è **vuoto**, e la riconciliazione
    // annulla tutto quello che c'è. Spegnere le notifiche deve spegnere anche
    // quelle già pianificate, non solo quelle future.
    if (!_notifiche.attive) return const {};

    final adesso = _adesso();
    final fine = adesso.add(_occorrenzeOltreLaFinestra);

    final occorrenze = [
      for (final occorrenza in _occorrenze(adesso, fine))
        if (occorrenza.event.allDay
            ? _notifiche.tuttoIlGiornoAttivo
            : _notifiche.eventoAttivo)
          occorrenza,
    ];

    final piano = {
      for (final avviso in planReminders(
        ReminderInputs(
          now: adesso,
          occurrences: occorrenze,
          todos: _notifiche.todoAttivo ? _todos() : const <Todo>[],
          doneOccurrences: _fatti(),
          eventLead: _notifiche.anticipoEventi,
          todoLead: _notifiche.anticipoTodo,
          todoMinuteOfDay: _notifiche.oraTodo,
          allDayMinuteOfDay: _notifiche.oraTuttoIlGiorno,
          soundDefault: _notifiche.suona,
        ),
        quiet: _notifiche.quietHours,
      ))
        avviso.id: avviso,
    };

    if (_notifiche.riepilogoAttivo && _cEQualcosaDaConfermare(adesso)) {
      for (final avviso in riepiloghiDellaSera(
        adesso: adesso,
        oraRiepilogo: _notifiche.oraRiepilogo,
        quiet: _notifiche.quietHours,
      )) {
        piano[avviso.id] = avviso;
      }
    }

    for (final avviso in NotificationActions(_db).rinvii(adesso, _notifiche)) {
      piano[avviso.id] = avviso;
    }
    return piano;
  }

  List<EventOccurrence> _occorrenze(DateTime from, DateTime to) =>
      occurrencesInWindow(
        from: from,
        to: to,
        singoli: [
          for (final row in _db.getEventsBetween(from, to)) Event.fromRow(row),
        ],
        ricorrenti: [
          for (final row in _db.getRecurringEvents()) Event.fromRow(row),
        ],
      );

  List<Todo> _todos() => [for (final row in _db.getTodos()) Todo.fromRow(row)];

  /// Le occorrenze già confermate (o i todo già fatti), nella forma che il
  /// pianificatore si aspetta: `elemento@AAAA-MM-GG`.
  Set<String> _fatti() {
    final perElemento = _db.occurrences.doneDaysByItem();
    return {
      for (final voce in perElemento.entries)
        for (final millesimi in voce.value)
          occurrenceKey(
            voce.key,
            DateTime.fromMillisecondsSinceEpoch(millesimi),
          ),
    };
  }

  /// Vero se c'è **qualcosa da confermare**: almeno un todo scaduto non fatto, o
  /// un'occorrenza di evento già passata e non confermata.
  ///
  /// È la stessa domanda che il foglio degli scaduti fa all'apertura, e la stessa
  /// finestra (30 giorni): il riepilogo della sera non arriva per dire «niente da
  /// fare». Un todo ricorrente non è coperto da questa occhiata — la sua
  /// scadenza è una serie, e il conto lo fa `todo_overdue.dart` per le viste:
  /// il caso comune (un todo con una data) sì.
  bool _cEQualcosaDaConfermare(DateTime adesso) {
    for (final todo in _todos()) {
      if (todo.completed) continue;
      final scadenza = todo.dueDate;
      if (scadenza != null && scadenza.isBefore(adesso)) return true;
    }

    final fatti = _fatti();
    final passato = _occorrenze(adesso.subtract(_scadutiIndietro), adesso);
    for (final occorrenza in passato) {
      if (!fatti
          .contains(occurrenceKey(occorrenza.event.id, occorrenza.date))) {
        return true;
      }
    }
    return false;
  }
}
