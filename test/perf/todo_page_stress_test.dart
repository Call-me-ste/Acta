import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/dev/stress_data.dart';
import 'package:planner/features/todos/todo_entry.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/todo_page.dart';
import 'package:planner/ui/mobile/todo_tile.dart';

import '../support/theme_providers.dart';

/// #161: la scheda Todo con il carico cattivo (2.000 todo). Misura il costo
/// dell'apertura; il numero da abbattere è quello misurato sul telefono
/// (164,5 ms) e questo è il banco JIT che deve scendere insieme.
void main() {
  testWidgets('baseline: primo frame di una pagina vuota', (tester) async {
    final watch = Stopwatch()..start();
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    watch.stop();
    // ignore: avoid_print
    print('PERF pagina vuota: primoFrame=${watch.elapsedMilliseconds} ms');
  });

  testWidgets('scheda Todo con 2.000 todo: costo di apertura', (tester) async {
    final db = DatabaseService();
    await db.init(dbPath: ':memory:');
    addTearDown(db.close);

    final seed = Stopwatch()..start();
    await StressData.load(db, from: DateTime(2026, 9, 14));
    seed.stop();

    final caricamento = Stopwatch()..start();
    final todos = TodoProvider(db);
    caricamento.stop();

    final vociWatch = Stopwatch()..start();
    final voci = [for (final todo in todos.todos) TodoEntry.of(todo, todos)];
    vociWatch.stop();

    final chiaveWatch = Stopwatch()..start();
    final chiave = [
      for (final voce in voci)
        '${voce.todo.id}:${voce.todo.version}:${voce.done}',
    ].join('|');
    chiaveWatch.stop();

    final providers = <SingleChildWidget>[
      ChangeNotifierProvider<TodoProvider>.value(value: todos),
      ...themeProviders(db),
    ];

    // Scalda i provider fuori dalla misura: l'apertura della pagina deve pagare
    // solo la pagina, non la creazione dei controller.
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();

    final apertura = Stopwatch()..start();
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: const MaterialApp(home: TodoPage()),
      ),
    );
    apertura.stop();

    final assestamento = Stopwatch()..start();
    await tester.pumpAndSettle();
    assestamento.stop();

    final tile =
        tester.widgetList(find.byType(TodoTile, skipOffstage: false)).length;
    // ignore: avoid_print
    print('PERF todo stress: seed=${seed.elapsedMilliseconds} ms, '
        'provider=${caricamento.elapsedMilliseconds} ms, '
        'voci=${vociWatch.elapsedMilliseconds} ms, '
        'chiave=${chiaveWatch.elapsedMilliseconds} ms '
        '(len ${chiave.length}), '
        'primoFrame=${apertura.elapsedMilliseconds} ms, '
        'assestamento=${assestamento.elapsedMilliseconds} ms, '
        'tile=$tile');

    expect(tester.takeException(), isNull);
  });
}
