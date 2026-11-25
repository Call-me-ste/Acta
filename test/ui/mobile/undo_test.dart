import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/todo_page.dart';

import '../../support/theme_providers.dart';

/// Cancellare per sbaglio non deve costare niente: c'è l'avviso con «Annulla»,
/// e il tocco prolungato fa quello che fa lo swipe (per chi lo swipe non lo fa).
void main() {
  late DatabaseService db;
  late TodoProvider todos;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ...themeProviders(db),
        ],
        child: const MaterialApp(home: TodoPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lo swipe cancella e «Annulla» rimette il todo', (tester) async {
    await todos.addTodo(title: 'Bolletta');
    await pumpPage(tester);
    expect(find.text('Bolletta'), findsOneWidget);

    await tester.drag(find.text('Bolletta'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Bolletta'), findsNothing);
    expect(find.text('Annulla'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(find.text('Bolletta'), findsOneWidget);
    expect(todos.todos.single.title, 'Bolletta');
  });

  testWidgets('il banner sparisce da solo dopo tre secondi', (tester) async {
    await todos.addTodo(title: 'Bolletta');
    await pumpPage(tester);

    await tester.drag(find.text('Bolletta'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Annulla'), findsOneWidget);

    // Il tempo passa: l'avviso se ne va **da solo** (era il difetto segnalato:
    // restava lì a coprire l'interfaccia).
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Annulla'), findsNothing);
    expect(find.text('Todo eliminato'), findsNothing);
  });

  testWidgets(
      "il tocco prolungato apre la selezione, e da li' si elimina con annulla",
      (tester) async {
    await todos.addTodo(title: 'Bolletta');
    await pumpPage(tester);

    // Dal 18/09 il tocco prolungato non cancella piu': apre la **selezione
    // multipla** (#90). La cancellazione per chi non scorre resta, ma passa da
    // li' - ed e' anche piu' sicura, perche' prima di sparire la riga si vede
    // selezionata.
    await tester.longPress(find.text('Bolletta'));
    await tester.pumpAndSettle();
    expect(find.text('1 selezionati'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('elimina-selezione')));
    await tester.pumpAndSettle();

    expect(find.text('Bolletta'), findsNothing);
    expect(find.text('Annulla'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(find.text('Bolletta'), findsOneWidget);
  });
}
