import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/overdue/domain/overdue_item.dart';
import 'package:planner/features/todos/todo_overdue.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/overdue_sheet.dart';

/// Il foglio delle conferme: limite di righe, «Fatto» che scrive, «No» che non
/// scrive niente (e quindi ricompare).
void main() {
  late DatabaseService db;
  late EventProvider events;
  late TodoProvider todos;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  Future<void> pumpSheet(WidgetTester tester, List<OverdueItem> items) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
        ],
        child: MaterialApp(
          home: Scaffold(body: OverdueSheet(items: items)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<OverdueItem> manyItems(int count) => [
        for (var i = 0; i < count; i++)
          OverdueItem(
            id: 't$i',
            title: 'Todo $i',
            date: DateTime(2026, 9, 1).add(Duration(days: i)),
            isEvent: false,
          ),
      ];

  testWidgets('oltre dieci righe si dice quante ne restano', (tester) async {
    await pumpSheet(tester, manyItems(12));

    expect(find.text('Fatto'), findsNWidgets(10));
    expect(find.text('e altri 2'), findsOneWidget);
  });

  testWidgets('«Fatto» su un todo lo completa e toglie la riga',
      (tester) async {
    await todos.addTodo(title: 'Bolletta', dueDate: DateTime(2026, 9, 1));
    final todo = todos.todos.single;

    await pumpSheet(tester, [
      OverdueItem(
        id: todo.id,
        title: 'Bolletta',
        date: DateTime(2026, 9, 1),
        isEvent: false,
      ),
    ]);

    await tester.tap(find.text('Fatto'));
    await tester.pumpAndSettle();

    expect(find.text('Bolletta'), findsNothing);
    expect(db.getTodos().single['completed'], 1);
  });

  testWidgets("«Fatto» su un evento scrive l'occorrenza", (tester) async {
    await events.addEvent(
      title: 'Dentista',
      start: DateTime(2026, 9, 10, 9),
      end: DateTime(2026, 9, 10, 10),
    );
    final event = events.events.single;

    await pumpSheet(tester, [
      OverdueItem(
        id: event.id,
        title: 'Dentista',
        date: DateTime(2026, 9, 10),
        isEvent: true,
      ),
    ]);

    await tester.tap(find.text('Fatto'));
    await tester.pumpAndSettle();

    expect(db.occurrences.isDone(event.id, DateTime(2026, 9, 10)), isTrue);
    expect(find.text('Dentista'), findsNothing);
  });

  testWidgets('«No» non scrive niente e lascia l\'elemento dov\'è',
      (tester) async {
    await todos.addTodo(title: 'Bolletta', dueDate: DateTime(2026, 9, 1));
    final todo = todos.todos.single;

    await pumpSheet(tester, [
      OverdueItem(
        id: todo.id,
        title: 'Bolletta',
        date: DateTime(2026, 9, 1),
        isEvent: false,
      ),
    ]);

    await tester.tap(find.text('Non ora'));
    await tester.pumpAndSettle();

    expect(find.text('Bolletta'), findsNothing);
    expect(db.getTodos().single['completed'], 0);
    // Nessuna scrittura: l'elemento è ancora scaduto, ricomparirà.
    expect(todos.overdue(30, until: DateTime(2026, 9, 15)), hasLength(1));
  });
}
