import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/dev/stress_data.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/month_grid.dart';

import '../support/theme_providers.dart';

/// Il banco di prova del calendario con il carico **cattivo**: 300 eventi nello
/// stesso giorno e 2.000 todo in un anno. Misura l'apertura e 15 tap rapidi fra
/// le tre viste; e' il numero che T1.2 deve far scendere.
void main() {
  testWidgets('calendario con dati stress: apertura e cambi rapidi',
      (tester) async {
    final db = DatabaseService();
    await db.init(dbPath: ':memory:');
    addTearDown(db.close);

    final giorno = DateTime(2026, 9, 14);
    final seed = Stopwatch()..start();
    await StressData.load(db, from: giorno);
    seed.stop();

    final caricamento = Stopwatch()..start();
    final events = EventProvider(db);
    final todos = TodoProvider(db);
    caricamento.stop();

    final apertura = Stopwatch()..start();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ...themeProviders(db),
        ],
        child: MaterialApp(home: CalendarPage(initialDay: giorno)),
      ),
    );
    await tester.pumpAndSettle();
    apertura.stop();

    final cambi = Stopwatch()..start();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Settimana'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.text('Giorno'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.text('Mese'));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    cambi.stop();

    // ignore: avoid_print
    print('PERF calendario stress: seed=${seed.elapsedMilliseconds} ms, '
        'provider=${caricamento.elapsedMilliseconds} ms, '
        'apertura=${apertura.elapsedMilliseconds} ms, '
        '15 tap=${cambi.elapsedMilliseconds} ms');

    expect(find.byType(MonthGrid), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(cambi.elapsedMilliseconds, lessThan(15000),
        reason: 'il banco di prova non deve andare in timeout: e\' un segnale '
            'di regressione grossolana, non un budget di fotogramma');
  });

  testWidgets(
      'calendario con dati stress: costo della prima apertura di ogni vista',
      (tester) async {
    final db = DatabaseService();
    await db.init(dbPath: ':memory:');
    addTearDown(db.close);

    final giorno = DateTime(2026, 9, 14);
    await StressData.load(db, from: giorno);
    final events = EventProvider(db);
    final todos = TodoProvider(db);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ...themeProviders(db),
        ],
        child: MaterialApp(home: CalendarPage(initialDay: giorno)),
      ),
    );
    await tester.pumpAndSettle();

    Future<int> apri(String etichetta) async {
      final watch = Stopwatch()..start();
      await tester.tap(find.text(etichetta));
      await tester.pumpAndSettle();
      watch.stop();
      return watch.elapsedMilliseconds;
    }

    final settimana = await apri('Settimana');
    final giornoCosto = await apri('Giorno');
    final mese = await apri('Mese');

    // ignore: avoid_print
    print('PERF viste stress: settimana=$settimana ms, giorno=$giornoCosto ms, '
        'mese=$mese ms');
  });
}
