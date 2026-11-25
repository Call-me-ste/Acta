import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/todos/todo_hidden.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_recurrence.dart';
import 'package:planner/features/todos/todo_windows.dart';

void main() {
  late DatabaseService db;
  late TodoProvider provider;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    provider = TodoProvider(db);
  });

  tearDown(() => db.close());

  test('addTodo genera uuid e la lista arriva ordinata per priorità', () async {
    await provider.addTodo(title: 'bassa', priority: 0);
    await provider.addTodo(title: 'urgente', priority: 3);

    expect(provider.todos.map((t) => t.title), ['urgente', 'bassa']);
    expect(provider.todos.map((t) => t.id).toSet(), hasLength(2));
    expect(provider.todos.first.completed, isFalse); // bool, non int
  });

  test('toggleTodo non lancia e commuta il valore', () async {
    // Regressione: la lettura restituiva `completed` come bool e il toggle lo
    // castava a int (`true as int`), quindi il tap sulla checkbox crashava.
    await provider.addTodo(title: 'spesa');
    final id = provider.todos.single.id;

    await provider.toggleTodo(id);
    expect(provider.todos.single.completed, isTrue);

    await provider.toggleTodo(id);
    expect(provider.todos.single.completed, isFalse);
  });

  test('updateTodo persiste priorità e scadenza, e sa azzerare la scadenza',
      () async {
    await provider.addTodo(title: 'spesa');
    final todo = provider.todos.single;

    await provider.updateTodo(
      todo.copyWith(priority: 2, dueDate: DateTime(2026, 9, 20)),
    );
    expect(provider.todos.single.priority, 2);
    expect(provider.todos.single.dueDate, DateTime(2026, 9, 20));

    // `null` esplicito azzera la scadenza: è il caso che il sentinella di
    // copyWith esiste per distinguere da "lascia com'è".
    await provider.updateTodo(provider.todos.single.copyWith(dueDate: null));
    expect(provider.todos.single.dueDate, isNull);
    expect(provider.todos.single.priority, 2); // il resto non cambia
  });

  test('deleteTodo rimuove la riga', () async {
    await provider.addTodo(title: 'usa e getta');

    await provider.deleteTodo(provider.todos.single.id);

    expect(provider.todos, isEmpty);
  });

  test('una finestra di giorni si calcola una volta, e si butta quando scrivi',
      () async {
    await provider.addTodo(title: 'singolo', dueDate: DateTime(2026, 9, 10));
    await provider.addTodo(
      title: 'ogni giorno',
      dueDate: DateTime(2026, 9, 1),
      recurrenceRule: 'FREQ=DAILY',
    );

    final dalla = DateTime(2026, 9, 1);
    final alla = DateTime(2026, 9, 30);
    final prima = provider.todosByDay(dalla, alla);

    // Stessa finestra, stesso oggetto: è il lavoro già fatto che si riusa.
    expect(identical(prima, provider.todosByDay(dalla, alla)), isTrue);
    // Il 10 settembre ci sono tutti e due (il singolo e l'occorrenza).
    expect(prima[DateTime(2026, 9, 10)]!.map((t) => t.title).toSet(),
        {'singolo', 'ogni giorno'});
    expect(prima[DateTime(2026, 9, 2)]!.map((t) => t.title), ['ogni giorno']);
    expect(prima[DateTime(2026, 10, 1)], isNull);

    // Una scrittura cambia quello che si vede: la finestra non si riusa.
    await provider.addTodo(title: 'nuovo', dueDate: DateTime(2026, 9, 10));
    final dopo = provider.todosByDay(dalla, alla);
    expect(identical(prima, dopo), isFalse);
    expect(dopo[DateTime(2026, 9, 10)]!.map((t) => t.title).toSet(),
        {'singolo', 'ogni giorno', 'nuovo'});
  });

  test('una conferma resta nella finestra, col segno di fatta', () async {
    await provider.addTodo(
      title: 'ogni giorno',
      dueDate: DateTime(2026, 9, 1),
      recurrenceRule: 'FREQ=DAILY',
    );
    final giorno = DateTime(2026, 9, 3);

    expect(provider.todosForDate(giorno), hasLength(1));
    await provider.completeOccurrence(provider.todos.single.id, giorno);

    // L'occorrenza **resta** nella finestra: si vede che e' fatta (barrata), ed
    // e' quello che e' stato chiesto. A toglierla dal calendario e' il segno
    // «via dal calendario», non la spunta.
    expect(provider.todosForDate(giorno), hasLength(1));
    expect(
      provider.isDoneOn(provider.todos.single, giorno),
      isTrue,
      reason: 'fatta **in quel giorno**, non per sempre: la serie continua',
    );
    expect(
      provider.isDoneOn(provider.todos.single, DateTime(2026, 9, 4)),
      isFalse,
    );
  });

  test('il segno toglie il todo dalla finestra, l\'annulla lo rimette',
      () async {
    await provider.addTodo(title: 'Spesa', dueDate: DateTime(2026, 9, 3));
    final todo = provider.todos.single;
    expect(provider.todosForDate(DateTime(2026, 9, 3)), hasLength(1));

    await provider.hideFromCalendar(todo);
    expect(
      provider.todosForDate(DateTime(2026, 9, 3)),
      isEmpty,
      reason: 'col segno il todo esce dalle griglie',
    );

    await provider.showInCalendar(todo);
    expect(
      provider.todosForDate(DateTime(2026, 9, 3)),
      hasLength(1),
      reason: 'l\'annulla lo rimette',
    );
  });
}
