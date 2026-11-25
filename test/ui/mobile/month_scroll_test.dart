import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';

import '../../support/theme_providers.dart';
import '../../support/grid.dart';

/// La vista mese si **scorre**: la griglia sale e gli eventi del giorno prendono
/// lo spazio. È la richiesta dell'utente, e il caso che contava era quello
/// **vuoto**: senza eventi non c'era niente da scorrere e il mese restava
/// bloccato.
void main() {
  late DatabaseService db;
  late EventProvider events;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
  });

  tearDown(() => db.close());

  Future<void> pumpPagina(WidgetTester tester, DateTime day) async {
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
        child: MaterialApp(home: CalendarPage(initialDay: day)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('scorrendo, la griglia sale e restano gli eventi',
      (tester) async {
    for (var i = 0; i < 8; i++) {
      await events.addEvent(
        title: 'Evento $i',
        start: DateTime(2026, 9, 14, 8 + i),
        end: DateTime(2026, 9, 14, 9 + i),
      );
    }

    await pumpPagina(tester, DateTime(2026, 9, 14));

    final calendario = grigliaDelMese(DateTime(2026, 9, 14));
    final prima = tester.getRect(calendario).top;

    await tester.drag(calendario, const Offset(0, -150));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(calendario).top,
      lessThan(prima),
      reason: 'la griglia non è salita: la pagina non scorre',
    );
    // Gli eventi del giorno sono ancora lì, sopra lo spazio liberato.
    expect(find.text('Evento 0'), findsOneWidget);
  });

  testWidgets('anche con il giorno vuoto la griglia sale', (tester) async {
    // Nessun evento: è il caso che l'utente vedeva bloccato ("troppo bloccato").
    await pumpPagina(tester, DateTime(2026, 9, 14));

    final calendario = grigliaDelMese(DateTime(2026, 9, 14));
    final prima = tester.getRect(calendario).top;

    await tester.drag(calendario, const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(calendario).top,
      lessThan(prima),
      reason: 'senza eventi la griglia non si muove: il mese resta bloccato',
    );
  });
}
