import '../events/domain/event.dart';
import '../events/event_provider.dart';
import 'domain/device_calendar_gateway.dart';

/// Un evento pronto per entrare nel Planner, già normalizzato dal calendario
/// esterno. Non ha un id: lo genera [EventProvider], come per ogni scrittura.
class ImportDraft {
  const ImportDraft({
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    this.description = '',
    this.location = '',
    this.colorHex,
    this.reminders = const [],
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String description;
  final String location;
  final String? colorHex;
  final List<int> reminders;

  String get fingerprint => [
        title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        allDay ? '1' : '0',
      ].join('|');
}

class ImportPlan {
  const ImportPlan({
    required this.drafts,
    required this.sourceCount,
    required this.duplicates,
  });

  final List<ImportDraft> drafts;

  /// Quanti eventi sono arrivati dal calendario (prima dei duplicati).
  final int sourceCount;

  /// Quanti erano già nel Planner o ripetuti nella stessa importazione.
  final int duplicates;

  int get importable => drafts.length;
}

class ImportResult {
  const ImportResult({required this.ids, required this.imported});

  final List<String> ids;
  final int imported;
}

/// Traduce gli eventi del telefono in eventi del Planner e li scrive.
///
/// Una tantum: le ricorrenze vengono **appiattite** nelle occorrenze del
/// periodo scelto. È una scelta voluta: il Planner non prova a ricostruire
/// regole che il calendario di sistema può rappresentare in modi diversi, e
/// l'import resta prevedibile.
class CalendarImportService {
  const CalendarImportService(this._events);

  final EventProvider _events;

  /// Costruisce l'anteprima senza scrivere niente. La chiave dei duplicati è
  /// titolo + inizio + fine + tutto-il-giorno: abbastanza stabile per un
  /// import una tantum, senza aggiungere colonne al database.
  ImportPlan plan(
    List<DeviceCalendarEvent> source, {
    Map<String, String?> calendarColors = const {},
  }) {
    final esistenti = {
      for (final evento in _events.events) _fingerprintOf(evento),
    };
    final visti = <String>{};
    final drafts = <ImportDraft>[];
    var duplicati = 0;

    for (final evento in source) {
      final colore = evento.colorHex ?? calendarColors[evento.calendarId];
      for (final draft in _draftsFor(evento, colore)) {
        if (esistenti.contains(draft.fingerprint) ||
            !visti.add(draft.fingerprint)) {
          duplicati++;
          continue;
        }
        drafts.add(draft);
      }
    }

    return ImportPlan(
      drafts: drafts,
      sourceCount: source.length,
      duplicates: duplicati,
    );
  }

  Future<ImportResult> import(ImportPlan piano) async {
    final ids = <String>[];
    for (final draft in piano.drafts) {
      final salvato = await _events.addEvent(
        title: draft.title,
        start: draft.start,
        end: draft.end,
        allDay: draft.allDay,
        description: draft.description,
        note: draft.description,
        location: draft.location,
        colorHex: draft.colorHex,
        // Vuoto = nessun avviso: un evento importato non deve iniziare a
        // suonare perché il Planner ha un default di 15 minuti.
        reminderLeads: draft.reminders,
        reminderSound: null,
      );
      ids.add(salvato.id);
    }
    return ImportResult(ids: ids, imported: ids.length);
  }

  Future<void> undo(List<String> ids) async {
    for (final id in ids) {
      await _events.deleteEvent(id);
    }
  }

  static String _fingerprintOf(Event evento) => [
        evento.title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
        evento.start.millisecondsSinceEpoch,
        evento.end.millisecondsSinceEpoch,
        evento.allDay ? '1' : '0',
      ].join('|');

  static List<ImportDraft> _draftsFor(
    DeviceCalendarEvent evento,
    String? colore,
  ) {
    final titolo =
        evento.title.trim().isEmpty ? 'Evento senza titolo' : evento.title;
    final testo = _testo(evento);
    final luogo = evento.location?.trim() ?? '';

    if (!evento.allDay) {
      var fine = evento.end;
      if (!fine.isAfter(evento.start)) {
        fine = evento.start.add(const Duration(hours: 1));
      }
      return [
        ImportDraft(
          title: titolo,
          start: evento.start,
          end: fine,
          allDay: false,
          description: testo,
          location: luogo,
          colorHex: colore,
          reminders: evento.reminders,
        ),
      ];
    }

    // Un evento di più giorni diventa un evento di giornata intera per ogni
    // giorno: il Planner rappresenta il «tutto il giorno» su una data sola.
    final primo = DateTime(
      evento.start.year,
      evento.start.month,
      evento.start.day,
    );
    var fineEsclusiva = DateTime(
      evento.end.year,
      evento.end.month,
      evento.end.day,
    );
    if (!fineEsclusiva.isAfter(primo)) {
      fineEsclusiva = primo.add(const Duration(days: 1));
    }
    final giorni = fineEsclusiva.difference(primo).inDays;
    return [
      for (var giorno = 0; giorno < giorni; giorno++)
        ImportDraft(
          title: titolo,
          start: primo.add(Duration(days: giorno)),
          end: DateTime(
            primo.year,
            primo.month,
            primo.day + giorno,
            23,
            59,
          ),
          allDay: true,
          description: testo,
          location: luogo,
          colorHex: colore,
          reminders: evento.reminders,
        ),
    ];
  }

  static String _testo(DeviceCalendarEvent evento) {
    final parti = <String>[
      if ((evento.description ?? '').trim().isNotEmpty)
        evento.description!.trim(),
      if ((evento.url ?? '').trim().isNotEmpty) evento.url!.trim(),
    ];
    return parti.join('\n\n');
  }
}
