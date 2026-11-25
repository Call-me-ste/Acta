import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/calendar_import/calendar_import_service.dart';
import 'package:planner/features/calendar_import/domain/device_calendar_gateway.dart';
import 'package:planner/features/events/event_provider.dart';

void main() {
  late DatabaseService db;
  late EventProvider events;
  late CalendarImportService service;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
    service = CalendarImportService(events);
  });

  tearDown(() => db.close());

  DeviceCalendarEvent timed({
    String id = 'e1',
    String title = 'Dentista',
    DateTime? start,
  }) {
    return DeviceCalendarEvent(
      eventId: id,
      instanceId: '$id@1',
      calendarId: 'cal-1',
      title: title,
      start: start ?? DateTime(2026, 9, 14, 9),
      end: (start ?? DateTime(2026, 9, 14, 9)).add(const Duration(hours: 1)),
      description: 'Portare la tessera',
      location: 'Via Roma 1',
      reminders: const [15, 60],
    );
  }

  test('un evento normale diventa un evento del Planner', () async {
    final piano = service.plan(
      [timed()],
      calendarColors: const {'cal-1': '#3366FF'},
    );

    expect(piano.importable, 1);
    final risultato = await service.import(piano);
    expect(risultato.imported, 1);

    final salvato = events.events.single;
    expect(salvato.title, 'Dentista');
    expect(salvato.start, DateTime(2026, 9, 14, 9));
    expect(salvato.end, DateTime(2026, 9, 14, 10));
    expect(salvato.location, 'Via Roma 1');
    expect(salvato.note, 'Portare la tessera');
    expect(salvato.reminderLeads, [15, 60]);
    expect(salvato.colorHex, '#3366FF');
    expect(salvato.allDay, isFalse);
  });

  test('lo stesso evento non entra due volte', () async {
    final primo = service.plan([timed()]);
    await service.import(primo);

    final secondo = service.plan([timed()]);
    expect(secondo.importable, 0);
    expect(secondo.duplicates, 1);
    expect(events.events, hasLength(1));
  });

  test('un evento di più giorni diventa una giornata per giorno', () async {
    final evento = DeviceCalendarEvent(
      eventId: 'ferie',
      instanceId: 'ferie@1',
      calendarId: 'cal-1',
      title: 'Ferie',
      start: DateTime(2026, 9, 14),
      end: DateTime(2026, 9, 16),
      allDay: true,
    );

    final piano = service.plan([evento]);
    expect(piano.importable, 2);
    await service.import(piano);

    final salvati = events.events..sort((a, b) => a.start.compareTo(b.start));
    expect(salvati, hasLength(2));
    expect(salvati.first.allDay, isTrue);
    expect(salvati.first.start, DateTime(2026, 9, 14));
    expect(salvati.last.start, DateTime(2026, 9, 15));
    expect(salvati.last.end, DateTime(2026, 9, 15, 23, 59));
  });

  test('le occorrenze di una serie restano eventi distinti', () async {
    final piano = service.plan([
      timed(id: 'serie', start: DateTime(2026, 9, 14, 9)),
      timed(id: 'serie', start: DateTime(2026, 9, 21, 9)),
    ]);

    expect(piano.importable, 2);
  });

  test('senza promemoria non eredita il default delle impostazioni', () async {
    final evento = DeviceCalendarEvent(
      eventId: 'senza-avviso',
      instanceId: 'senza-avviso@1',
      calendarId: 'cal-1',
      title: 'Senza avviso',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    );

    await service.import(service.plan([evento]));
    expect(events.events.single.reminderLeads, isEmpty);
  });

  test('annulla rimuove solo gli eventi importati', () async {
    final piano = service.plan([timed()]);
    final risultato = await service.import(piano);
    expect(events.events, hasLength(1));

    await service.undo(risultato.ids);
    expect(events.events, isEmpty);
  });
}
