import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_provider.dart';

/// Il ripristino dopo una cancellazione deve **vincere** sulla cancellazione.
///
/// Se il clock non sale, il record di cancellazione (che ha già la versione più
/// alta) batte il ripristino quando arriva da un altro dispositivo: l'utente
/// annulla, e l'elemento sparisce di nuovo. Per questo la versione sale di due:
/// la riga era V, la cancellazione ha scritto V+1, il ripristino V+2.
void main() {
  late DatabaseService db;
  late TodoProvider todos;
  late EventProvider events;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    todos = TodoProvider(db);
    events = EventProvider(db);
  });

  tearDown(() => db.close());

  test('il todo rimesso sta sopra la cancellazione come clock', () async {
    await todos.addTodo(title: 'Bolletta');
    final todo = todos.todos.single;
    expect(todo.version, 1);

    await todos.deleteTodo(todo.id);
    expect(db.getTodos(), isEmpty);

    await todos.restoreTodo(todo);

    expect(todos.todos.single.title, 'Bolletta');
    expect(
      db.getTodos().single['version'],
      3,
      reason:
          'la cancellazione aveva scritto 2: il ripristino deve stare sopra',
    );
  });

  test("l'evento rimesso sta sopra la cancellazione come clock", () async {
    await events.addEvent(
      title: 'Riunione',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    );
    final event = events.events.single;

    await events.deleteEvent(event.id);
    expect(db.getEvents(), isEmpty);

    await events.restoreEvent(event);

    expect(events.events.single.title, 'Riunione');
    expect(db.getEvents().single['version'], 3);
  });
}
