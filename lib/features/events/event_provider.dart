import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_service.dart';
import '../../core/database/occurrence_commands.dart';
import '../overdue/domain/overdue_item.dart';
import 'domain/event.dart';
import 'domain/event_occurrence.dart';
import 'domain/event_series.dart';

/// Stato degli eventi. La UI non tocca mai il DB: legge da qui, e qui ogni
/// scrittura passa da SQL parametrizzato.
///
/// Da questa versione ogni scrittura lascia anche una voce in outbox, **nella
/// stessa transazione** del dato: è la coda che il sync spinge. Se una delle due
/// fallisce, non resta metà scrittura.
class EventProvider extends ChangeNotifier {
  // Niente lettura all'avvio: la tabella si legge alla prima richiesta (vedi
  // `events`), così l'apertura dell'app non paga un archivio lungo che nessuno
  // ha ancora chiesto.
  EventProvider(this._db);

  final DatabaseService _db;
  static const _uuid = Uuid();
  static const String _entity = 'event';

  /// Gli eventi letti dal database, **alla prima richiesta** dopo una scrittura.
  ///
  /// Prima ogni salvataggio rileggeva l'intera tabella (e la riparsava) per
  /// riempire una lista che nessuna vista usa — verificato con grep: `events`
  /// serve solo ai test. Con un archivio lungo era lavoro sprecato a ogni tocco.
  /// Ora la lista si costruisce quando qualcuno la chiede e si butta a ogni
  /// scrittura: la garanzia è la stessa, pagata solo se serve.
  int _generazione = 0;

  /// Quante volte i dati sono cambiati. Serve alla memoria delle viste del
  /// calendario: una vista che non si guardava non si e' ricostruita, quindi
  /// alla prossima occhiata deve sapere che quello che ha in mano e' vecchio.
  /// Sale su ogni scrittura, non sulle letture.
  int get generazione => _generazione;

  List<Event>? _events;

  List<Event> get events =>
      _events ??= _db.getEvents().map(Event.fromRow).toList();

  /// Rilegge tutto dal database: serve a chi scrive **fuori** dai provider (i
  /// dati di prova), altrimenti le viste restano con la copia in memoria.
  void reload() => _invalidate();

  /// A scrittura avvenuta: quello che sta in memoria non vale più e chi ascolta
  /// va avvisato. Il database resta l'unica fonte di verità (le viste leggono
  /// da lì, con le loro query di finestra).
  void _invalidate() {
    _generazione++;
    _events = null;
    // Le finestre cambiano a ogni scrittura: si ricalcolano alla prima lettura.
    _windows.clear();
    notifyListeners();
  }

  /// Le finestre di occorrenze già calcolate.
  ///
  /// Perché serve: `occurrencesBetween` rilegge il database **e** espande le
  /// ricorrenze a ogni chiamata, e ogni vista la chiama mentre si disegna. Il
  /// primo cambio vista pagava quindi lettura + espansione dentro il fotogramma
  /// dell'animazione: è lo scatto che si vedeva. Le viste chiedono sempre le
  /// stesse finestre (il mese, la settimana, i tre giorni vivi, l'agenda), quindi
  /// il risultato si tiene e si riusa. Otto in memoria — le finestre in gioco
  /// insieme sono al massimo sei — e si svuota a ogni scrittura, come le
  /// finestre dei todo.
  final Map<(int, int), List<EventOccurrence>> _windows = {};
  static const int _maxWindows = 8;

  /// Le occorrenze che cadono nella finestra `[from, to)`.
  ///
  /// Sono eventi concreti **più** le occorrenze dei ricorrenti: mai gli uni
  /// mescolati con le serie, e mai il template mostrato come sé stesso.
  ///
  /// La lista che torna è **condivisa** con la cache: chi la riceve non la
  /// modifica (nessuno lo fa: si legge e si disegna).
  List<EventOccurrence> occurrencesBetween(DateTime from, DateTime to) {
    final key = (from.millisecondsSinceEpoch, to.millisecondsSinceEpoch);
    final cached = _windows[key];
    if (cached != null) return cached;

    final calcolate = _computeOccurrences(from, to);
    if (_windows.length >= _maxWindows) _windows.remove(_windows.keys.first);
    _windows[key] = calcolate;
    return calcolate;
  }

  List<EventOccurrence> _computeOccurrences(DateTime from, DateTime to) {
    return occurrencesInWindow(
      from: from,
      to: to,
      singoli: [
        for (final row in _db.getEventsBetween(from, to)) Event.fromRow(row),
      ],
      ricorrenti: [
        for (final row in _db.getRecurringEvents()) Event.fromRow(row),
      ],
    );
  }

  /// Le occorrenze di un solo giorno. La data dell'occorrenza è la chiave con
  /// cui la vista raggruppa: è questo che tiene un evento ricorrente in un
  /// giorno solo.
  List<EventOccurrence> occurrencesForDate(DateTime day) {
    final from = _dayOnly(day);
    return occurrencesBetween(from, from.add(const Duration(days: 1)));
  }

  bool isOccurrenceDone(String eventId, DateTime day) =>
      _db.occurrences.isDone(eventId, day);

  /// Conferma un'occorrenza di evento ("è stato fatto"): la conferma vive nella
  /// tabella delle occorrenze, la stessa dei todo, quindi entra nel sync senza
  /// codice nuovo.
  void confirmOccurrence(String eventId, DateTime day) {
    _db.markOccurrenceDone(
      itemId: eventId,
      day: day,
      operationId: _uuid.v4(),
    );
    notifyListeners();
  }

  /// Le occorrenze passate e non confermate, entro la finestra. L'evento di
  /// oggi non è "scaduto": la giornata non è finita.
  List<OverdueItem> overdue(int days, {required DateTime until}) {
    final today = _dayOnly(until);
    final windowStart = DateTime(today.year, today.month, today.day - days);
    final items = <OverdueItem>[];

    for (final occurrence in occurrencesBetween(windowStart, today)) {
      if (isOccurrenceDone(occurrence.event.id, occurrence.date)) continue;
      items.add(
        OverdueItem(
          id: occurrence.event.id,
          title: occurrence.title,
          date: occurrence.date,
          isEvent: true,
        ),
      );
    }
    return items;
  }

  Future<Event> addEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String description = '',
    int colorIndex = 0,
    String? colorHex,
    String recurrenceRule = '',
    bool allDay = false,
    String location = '',
    String note = '',
    List<String> categoryIds = const [],
    List<int>? reminderLeads,
    bool? reminderSound,
  }) async {
    final event = Event(
      id: _uuid.v4(),
      title: title,
      description: description,
      start: start,
      end: end,
      allDay: allDay,
      colorIndex: colorIndex,
      colorHex: colorHex,
      recurrenceRule: recurrenceRule,
      location: location,
      note: note,
      categoryIds: categoryIds,
      reminderLeads: reminderLeads,
      reminderSound: reminderSound,
      updatedAt: DateTime.now(),
    );

    _write(
      () => _db.insertEvent(event.toParams()),
      id: event.id,
      version: event.version,
      updatedAt: event.updatedAt!,
      payload: event.toParams(),
    );
    _invalidate();
    return event;
  }

  Future<void> updateEvent(Event event) async {
    // Ogni modifica avanza il clock: è quello che il sync confronta per capire
    // chi ha l'ultima parola.
    final next = event.copyWith(
      version: event.version + 1,
      updatedAt: DateTime.now(),
    );

    _write(
      () => _db.updateEvent(next.toParams()),
      id: next.id,
      version: next.version,
      updatedAt: next.updatedAt!,
      payload: next.toParams(),
    );
    _invalidate();
  }

  Future<void> deleteEvent(String id) async {
    final clock = _db.entities.localClock(_entity, id);
    final now = DateTime.now();

    _write(
      () => _db.deleteEvent(id),
      id: id,
      // La cancellazione ha una versione **più alta** di quella della riga: è
      // così che vince su un aggiornamento più vecchio arrivato da un altro
      // dispositivo.
      version: (clock?.$1 ?? 0) + 1,
      updatedAt: now,
      // payload null = cancellazione: nel record non viaggia nessun dato.
      payload: null,
    );
    _invalidate();
  }

  /// Rimette un evento cancellato per sbaglio (l'undo dell'avviso).
  ///
  /// La versione sale di **due**: la cancellazione aveva già avanzato il clock
  /// di uno, e il ripristino deve vincere su quel record — altrimenti un altro
  /// dispositivo, con la cancellazione in mano, lo elimina di nuovo. Non si può
  /// leggere il clock dalla riga: dopo la cancellazione la riga non c'è più.
  Future<void> restoreEvent(Event event) async {
    final next = event.copyWith(
      version: event.version + 2,
      updatedAt: DateTime.now(),
    );

    _write(
      () => _db.insertEvent(next.toParams()),
      id: next.id,
      version: next.version,
      updatedAt: next.updatedAt!,
      payload: next.toParams(),
    );
    _invalidate();
  }

  void _write(
    void Function() apply, {
    required String id,
    required int version,
    required DateTime updatedAt,
    required Map<String, Object?>? payload,
  }) {
    _db.runInTransaction(() {
      apply();
      _db.outbox.enqueue(
        operationId: _uuid.v4(),
        entity: _entity,
        entityId: id,
        operation: payload == null ? 'delete' : 'upsert',
        version: version,
        updatedAt: updatedAt.millisecondsSinceEpoch,
        payload: payload ?? const {},
      );
    });
  }

  static DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
