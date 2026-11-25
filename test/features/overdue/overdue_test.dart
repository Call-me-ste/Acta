import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/overdue/domain/overdue_item.dart';
import 'package:planner/features/todos/todo_overdue.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_recurrence.dart';

/// Gli scaduti da confermare: la finestra, cosa resta fuori e le due risposte.
///
/// La data di riferimento arriva **da fuori** (`until`): un test che dipende da
/// `DateTime.now()` cambia esito a mezzanotte — è successo davvero, e ha fatto
/// fallire il test dell'agenda mentre la sessione era aperta.
void main() {
  late DatabaseService db;
  late EventProvider events;
  late TodoProvider todos;

  final today = DateTime(2026, 9, 15);

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  test('un evento passato dentro la finestra è scaduto', () async {
    await events.addEvent(
      title: 'Dentista',
      start: DateTime(2026, 9, 10, 9),
      end: DateTime(2026, 9, 10, 10),
    );

    final items = events.overdue(30, until: today);

    expect(items, hasLength(1));
    expect(items.single.title, 'Dentista');
    expect(items.single.date, DateTime(2026, 9, 10));
    expect(items.single.isEvent, isTrue);
  });

  test("l'evento di oggi non è scaduto: la giornata non è finita", () async {
    await events.addEvent(
      title: 'Oggi',
      start: DateTime(2026, 9, 15, 9),
      end: DateTime(2026, 9, 15, 10),
    );

    expect(events.overdue(30, until: today), isEmpty);
  });

  test('la finestra taglia: 30 giorni dentro, 31 fuori', () async {
    await events.addEvent(
      title: 'Limite',
      start: DateTime(2026, 8, 16, 9),
      end: DateTime(2026, 8, 16, 10),
    );
    await events.addEvent(
      title: 'Fuori',
      start: DateTime(2026, 8, 15, 9),
      end: DateTime(2026, 8, 15, 10),
    );

    final items = events.overdue(30, until: today);

    expect(items.map((item) => item.title), ['Limite']);
  });

  test('un evento confermato non è più scaduto', () async {
    await events.addEvent(
      title: 'Fatto',
      start: DateTime(2026, 9, 10, 9),
      end: DateTime(2026, 9, 10, 10),
    );
    final event = events.events.single;
    events.confirmOccurrence(event.id, DateTime(2026, 9, 10));

    expect(events.overdue(30, until: today), isEmpty);
    expect(db.occurrences.isDone(event.id, DateTime(2026, 9, 10)), isTrue);
  });

  test('un todo singolo resta scaduto a qualunque età', () async {
    await todos.addTodo(title: 'Vecchio', dueDate: DateTime(2026, 5, 1));

    final items = todos.overdue(30, until: today);

    expect(items, hasLength(1));
    expect(items.single.isEvent, isFalse);
  });

  test('un todo completato non è scaduto', () async {
    await todos.addTodo(title: 'Fatto', dueDate: DateTime(2026, 9, 1));
    await todos.toggleTodo(todos.todos.single.id);

    expect(todos.overdue(30, until: today), isEmpty);
  });

  test('di un ricorrente contano le occorrenze passate', () async {
    await todos.addTodo(
      title: 'Palestra',
      dueDate: DateTime(2026, 9, 1),
      recurrenceRule: 'FREQ=DAILY',
    );

    // Finestra di 3 giorni su "oggi 15": 12, 13 e 14 settembre.
    expect(todos.overdue(3, until: today), hasLength(3));

    todos.confirmOverdue(todos.todos.single.id, DateTime(2026, 9, 13));

    expect(todos.overdue(3, until: today), hasLength(2));
  });

  test("l'elenco finale è ordinato dal più vecchio", () async {
    await events.addEvent(
      title: 'Evento',
      start: DateTime(2026, 9, 12, 9),
      end: DateTime(2026, 9, 12, 10),
    );
    await todos.addTodo(title: 'Todo', dueDate: DateTime(2026, 9, 1));

    final items = sortedOverdue(
      events.overdue(30, until: today),
      todos.overdue(30, until: today),
    );

    expect(items.map((item) => item.title), ['Todo', 'Evento']);
  });
}
