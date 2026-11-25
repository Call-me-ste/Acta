import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/day_view.dart';

import '../../support/finders.dart';
import '../../support/theme_providers.dart';
import '../../support/grid.dart';

/// Tocco prolungato su un giorno nella vista mese: si apre **quel** giorno nella
/// vista giorno, non "una" vista giorno. La prova è un evento seminato in quel
/// giorno più un'esca nel giorno dopo: se si aprisse il giorno sbagliato, l'esca
/// comparirebbe al posto suo.
void main() {
  late DatabaseService db;
  late EventProvider events;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
  });

  tearDown(() => db.close());

  testWidgets('tenere premuto un giorno apre la vista giorno di quel giorno',
      (tester) async {
    await events.addEvent(
      title: 'Riunione del 16',
      start: DateTime(2026, 9, 16, 9),
      end: DateTime(2026, 9, 16, 10),
    );
    await events.addEvent(
      title: 'Esca del 17',
      start: DateTime(2026, 9, 17, 9),
      end: DateTime(2026, 9, 17, 10),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
          ...themeProviders(db),
        ],
        child: MaterialApp(
          home: CalendarPage(initialDay: DateTime(2026, 9, 14)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calendarFinder, findsOneWidget);

    // Tocco prolungato sul 16 (il giorno selezionato è il 14).
    await tieniPremutoIlGiorno(tester, DateTime(2026, 9, 16));
    await tester.pumpAndSettle();

    expect(find.byType(DayView), findsOneWidget);
    expect(calendarFinder, findsNothing);
    expect(find.text('Riunione del 16'), findsOneWidget);
    expect(find.text('Esca del 17'), findsNothing);
  });
}
