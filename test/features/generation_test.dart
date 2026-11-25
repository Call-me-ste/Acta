import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_overdue.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_recurrence.dart';
import 'package:planner/features/todos/todo_windows.dart';

/// Il contatore di generazione dei due provider.
///
/// Serve alla memoria delle viste del calendario: una vista che non si guardava
/// non si e' ricostruita, e il contatore e' quello che le dice — appena torna in
/// scena — che quello che ha in mano e' vecchio. Se salisse anche su una lettura,
/// ogni ridisegno butterebbe la memoria e si tornerebbe al costo di partenza; se
/// non salisse su una scrittura, la vista mostrerebbe dati vecchi.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  test('nei todo sale a ogni scrittura e non sulle letture', () async {
    final todos = TodoProvider(db);
    final partenza = todos.generazione;

    await todos.addTodo(title: 'Pane', dueDate: DateTime(2026, 9, 15));
    expect(todos.generazione, partenza + 1);

    // Le letture non sono cambiamenti: la griglia del mese le fa a ogni disegno.
    todos.todosByDay(DateTime(2026, 9, 1), DateTime(2026, 10, 1));
    todos.todosForDate(DateTime(2026, 9, 15));
    todos.overdue(30, until: DateTime(2026, 9, 20));
    expect(todos.generazione, partenza + 1);

    final todo = todos.todos.single;
    await todos.toggleTodo(todo.id);
    expect(todos.generazione, partenza + 2);

    await todos.completeOccurrence(todo.id, DateTime(2026, 9, 15));
    expect(todos.generazione, partenza + 3);

    await todos.deleteTodo(todo.id);
    expect(todos.generazione, partenza + 4);

    todos.reload();
    expect(todos.generazione, partenza + 5);
  });

  test('negli eventi sale a ogni scrittura e non sulle letture', () async {
    final events = EventProvider(db);
    final partenza = events.generazione;

    await events.addEvent(
      title: 'Palestra',
      start: DateTime(2026, 9, 14, 18),
      end: DateTime(2026, 9, 14, 19),
    );
    expect(events.generazione, partenza + 1);

    events.occurrencesBetween(DateTime(2026, 9, 1), DateTime(2026, 10, 1));
    events.occurrencesForDate(DateTime(2026, 9, 14));
    events.overdue(30, until: DateTime(2026, 9, 20));
    expect(events.generazione, partenza + 1);

    final event = events.events.single;
    await events.updateEvent(event.copyWith(title: 'Corsa'));
    expect(events.generazione, partenza + 2);

    await events.deleteEvent(event.id);
    expect(events.generazione, partenza + 3);

    events.reload();
    expect(events.generazione, partenza + 4);
  });
}
