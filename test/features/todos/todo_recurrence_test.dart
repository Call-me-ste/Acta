import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_recurrence.dart';

void main() {
  late DatabaseService db;
  late TodoProvider provider;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    provider = TodoProvider(db);
  });

  tearDown(() => db.close());

  test('un todo ricorrente mostra la prossima occorrenza, una riga sola',
      () async {
    // 2026-09-14 è un lunedì; sabato 19 la prossima è lunedì 21.
    await provider.addTodo(
      title: 'Ufficio',
      dueDate: DateTime(2026, 9, 14),
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
    );

    final todo = provider.todos.single;
    expect(provider.todos, hasLength(1),
        reason: 'una riga, non una per giorno');
    expect(provider.nextOccurrence(todo, from: DateTime(2026, 9, 14)),
        DateTime(2026, 9, 14));
    expect(provider.nextOccurrence(todo, from: DateTime(2026, 9, 19)),
        DateTime(2026, 9, 21));
  });

  test('una serie finita non ha prossima occorrenza', () async {
    await provider.addTodo(
      title: 'Corso',
      dueDate: DateTime(2026, 9, 14),
      recurrenceRule: 'FREQ=DAILY;UNTIL=2026-09-16',
    );

    final todo = provider.todos.single;
    expect(provider.nextOccurrence(todo, from: DateTime(2026, 9, 15)),
        DateTime(2026, 9, 15));
    expect(provider.nextOccurrence(todo, from: DateTime(2026, 9, 17)), isNull);
  });

  test('senza regola o senza data non c\'è ricorrenza', () async {
    await provider.addTodo(title: 'Semplice', dueDate: DateTime(2026, 9, 14));
    await provider.addTodo(title: 'Senza data');

    expect(provider.nextOccurrence(provider.todos.first), isNull);
    expect(provider.nextOccurrence(provider.todos.last), isNull);
  });

  test('spuntare segna solo quell\'occorrenza, non la serie', () async {
    await provider.addTodo(
      title: 'Acqua',
      dueDate: DateTime(2026, 9, 14),
      recurrenceRule: 'FREQ=DAILY',
    );
    final todo = provider.todos.single;

    await provider.completeOccurrence(todo.id, DateTime(2026, 9, 14));

    expect(provider.isOccurrenceDone(todo.id, DateTime(2026, 9, 14)), isTrue);
    expect(provider.isOccurrenceDone(todo.id, DateTime(2026, 9, 15)), isFalse);
    // La serie resta non completata: "l'ho fatto oggi" non è "non lo faccio più".
    expect(provider.todos.single.completed, isFalse);

    // E l'occorrenza viaggia nel sync come qualsiasi altra entità.
    expect(db.outbox.pending().last['entity_type'], 'occurrence_override');
  });

  test('rifare la stessa occorrenza avanza il clock senza duplicare', () async {
    await provider.addTodo(
      title: 'Acqua',
      dueDate: DateTime(2026, 9, 14),
      recurrenceRule: 'FREQ=DAILY',
    );
    final todo = provider.todos.single;

    await provider.completeOccurrence(todo.id, DateTime(2026, 9, 14));
    await provider.completeOccurrence(todo.id, DateTime(2026, 9, 14));

    final rows = db.instance.select(
      'SELECT * FROM occurrence_overrides WHERE item_id = ?',
      [todo.id],
    );
    expect(rows, hasLength(1), reason: 'una riga per (item, data)');
    expect(rows.single['version'], 2);
  });
}
