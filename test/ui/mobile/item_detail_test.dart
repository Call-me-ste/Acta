import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/item_detail_sheet.dart';
import 'package:planner/ui/mobile/item_form.dart';

import '../../support/theme_providers.dart';

/// Il tocco apre la **scheda**, non il form: modificare è una scelta esplicita.
void main() {
  late DatabaseService db;
  late EventProvider eventi;
  late TodoProvider todos;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    eventi = EventProvider(db);
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  Future<void> apri(WidgetTester tester, Future<void> Function(BuildContext) onTap) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: db),
          ChangeNotifierProvider<EventProvider>.value(value: eventi),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ...themeProviders(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () { onTap(context); },
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('il todo apre la scheda con Modifica esplicito', (tester) async {
    await todos.addTodo(title: 'Comprare latte', priority: 2);
    final todo = todos.todos.single;
    await apri(
      tester,
      (context) => showItemDetail(context, todo: todo),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.text('Comprare latte'), findsOneWidget);
    expect(find.text('To do'), findsOneWidget);
    expect(find.textContaining('Priorità: Alta'), findsOneWidget);
    expect(find.byKey(const ValueKey('dettaglio-modifica')), findsOneWidget);
    expect(find.byType(ItemForm), findsNothing);

    await tester.tap(find.byKey(const ValueKey('dettaglio-modifica')));
    await tester.pumpAndSettle();
    expect(find.byType(ItemForm), findsOneWidget);
  });

  testWidgets('l\'evento apre la scheda con orario e Modifica',
      (tester) async {
    await eventi.addEvent(
      title: 'Dentista',
      start: DateTime(2026, 10, 23, 9),
      end: DateTime(2026, 10, 23, 10),
      location: 'Via Roma 1',
    );
    final evento = eventi.events.single;
    await apri(
      tester,
      (context) => showItemDetail(context, event: evento),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.text('Dentista'), findsOneWidget);
    expect(find.text('Evento'), findsOneWidget);
    expect(find.textContaining('09:00'), findsOneWidget);
    expect(find.textContaining('Via Roma 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('dettaglio-elimina')), findsOneWidget);
  });

  testWidgets('dalla scheda si spunta un todo', (tester) async {
    await todos.addTodo(title: 'Pane');
    final todo = todos.todos.single;
    await apri(
      tester,
      (context) => showItemDetail(context, todo: todo),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dettaglio-spunta')));
    await tester.pumpAndSettle();

    expect(todos.todos.single.completed, isTrue);
  });
}


