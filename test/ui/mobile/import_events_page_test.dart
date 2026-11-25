import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/calendar_import/domain/device_calendar_gateway.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/ui/mobile/import_events_page.dart';

class _FakeGateway implements DeviceCalendarGateway {
  _FakeGateway({this.access = CalendarAccess.granted});

  final CalendarAccess access;
  final availableCalendars = <DeviceCalendarInfo>[
    const DeviceCalendarInfo(
      id: 'cal-1',
      name: 'Personale',
      accountName: 'stefano@gmail.com',
    ),
  ];
  final sourceEvents = <DeviceCalendarEvent>[
    DeviceCalendarEvent(
      eventId: 'e1',
      instanceId: 'e1@1',
      calendarId: 'cal-1',
      title: 'Dentista',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    ),
    DeviceCalendarEvent(
      eventId: 'e2',
      instanceId: 'e2@1',
      calendarId: 'cal-1',
      title: 'Palestra',
      start: DateTime(2026, 9, 15, 18),
      end: DateTime(2026, 9, 15, 19),
    ),
  ];

  @override
  Future<CalendarAccess> requestAccess() async => access;

  @override
  Future<List<DeviceCalendarInfo>> calendars() async => availableCalendars;

  @override
  Future<List<DeviceCalendarEvent>> events({
    required Set<String> calendarIds,
    required DateTime from,
    required DateTime to,
  }) async =>
      [
        for (final evento in sourceEvents)
          if (calendarIds.contains(evento.calendarId)) evento,
      ];

  @override
  Future<void> openSettings() async {}
}

void main() {
  late DatabaseService db;
  late EventProvider provider;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    provider = EventProvider(db);
  });

  tearDown(() => db.close());

  Future<void> pumpPage(WidgetTester tester, _FakeGateway gateway) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<EventProvider>.value(
        value: provider,
        child: MaterialApp(
          home: ImportEventsPage(gateway: gateway),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra calendari, anteprima e importa', (tester) async {
    await pumpPage(tester, _FakeGateway());

    expect(find.text('Personale'), findsOneWidget);
    expect(find.text('2 eventi da importare'), findsOneWidget);
    expect(find.text('Importa 2 eventi'), findsOneWidget);

    await tester.tap(find.text('Importa 2 eventi'));
    await tester.pumpAndSettle();

    expect(provider.events, hasLength(2));
    expect(find.text('2 eventi importati.'), findsOneWidget);
  });

  testWidgets('i calendari in sola lettura restano fuori dal one-click',
      (tester) async {
    final gateway = _FakeGateway();
    gateway.availableCalendars.addAll(const [
      DeviceCalendarInfo(
        id: 'cal-2',
        name: 'Festività',
        accountName: 'stefano@gmail.com',
        readOnly: true,
      ),
      DeviceCalendarInfo(
        id: 'cal-3',
        name: 'Festività',
        accountName: 'altro@gmail.com',
        readOnly: true,
      ),
    ]);
    gateway.sourceEvents.add(
      DeviceCalendarEvent(
        eventId: 'e3',
        instanceId: 'e3@1',
        calendarId: 'cal-2',
        title: 'Natale',
        start: DateTime(2026, 12, 25),
        end: DateTime(2026, 12, 26),
        allDay: true,
      ),
    );

    await pumpPage(tester, gateway);

    expect(find.text('Festività e calendari di sistema'), findsOneWidget);
    expect(find.text('2 eventi da importare'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('importa-sistema')));
    await tester.pumpAndSettle();
    // Due calendari «Festività» su account diversi: una sola riga.
    expect(find.text('Festività'), findsOneWidget);
    expect(find.textContaining('stefano@gmail.com, altro@gmail.com'),
        findsOneWidget);
  });

  testWidgets('calendari omonimi su account diversi restano due gruppi',
      (tester) async {
    final gateway = _FakeGateway();
    gateway.availableCalendars
      ..clear()
      ..addAll(const [
        DeviceCalendarInfo(
          id: 'a1',
          name: 'Famiglia',
          accountName: 'a@example.com',
        ),
        DeviceCalendarInfo(
          id: 'a2',
          name: 'Famiglia',
          accountName: 'a@example.com',
        ),
        DeviceCalendarInfo(
          id: 'b1',
          name: 'Famiglia',
          accountName: 'b@example.com',
        ),
        DeviceCalendarInfo(
          id: 'b2',
          name: 'Famiglia',
          accountName: 'b@example.com',
        ),
      ]);
    gateway.sourceEvents.clear();

    await pumpPage(tester, gateway);

    // Due gruppi distinti, non una riga sola: gli account restano leggibili.
    expect(find.text('Famiglia'), findsNWidgets(2));
    expect(find.textContaining('a@example.com'), findsOneWidget);
    expect(find.textContaining('b@example.com'), findsOneWidget);
  });

  testWidgets('«local account» diventa un nome comprensibile', (tester) async {
    final gateway = _FakeGateway();
    gateway.availableCalendars
      ..clear()
      ..addAll(const [
        DeviceCalendarInfo(
          id: 'local',
          name: 'local account',
          accountName: 'local account',
        ),
        DeviceCalendarInfo(
          id: 'local-2',
          name: 'Calendario locale',
          accountType: 'local',
        ),
      ]);
    gateway.sourceEvents.clear();

    await pumpPage(tester, gateway);

    // Due righe OEM identiche: una sola voce in elenco.
    expect(find.text('Calendario locale'), findsOneWidget);
    expect(
      find.text('2 calendari locali · solo su questo telefono'),
      findsOneWidget,
    );
  });

  testWidgets('senza permesso spiega cosa serve e non importa', (tester) async {
    await pumpPage(tester, _FakeGateway(access: CalendarAccess.denied));

    expect(
      find.textContaining('serve il permesso di leggere il calendario'),
      findsOneWidget,
    );
    expect(find.text('Consenti accesso al calendario'), findsOneWidget);
    expect(provider.events, isEmpty);
  });
}
