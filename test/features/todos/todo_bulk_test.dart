import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_selection.dart';

/// Le fondamenta della **selezione multipla** (#90): la scrittura in blocco e
/// chi e' selezionato.
///
/// La scrittura in blocco e' una sola transazione: o passano tutti, o nessuno. La
/// prova della atomicita' sta in fondo (`runInTransaction` che fallisce): il
/// blocco la usa, e non ha una seconda strada per scrivere.
void main() {
  late DatabaseService db;
  late TodoProvider todos;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  test('spuntare molti todo li scrive tutti, con la versione avanzata',
      () async {
    await todos.addTodo(title: 'Uno');
    await todos.addTodo(title: 'Due');

    final voci = [
      for (final todo in todos.todos) (todo, todo.copyWith(completed: true)),
    ];
    todos.scriviMolti(voci);

    expect(todos.todos.every((todo) => todo.completed), isTrue);
    expect(db.getTodos().every((row) => row['completed'] == 1), isTrue);
    expect(db.getTodos().map((row) => row['version']), everyElement(2),
        reason: 'ogni riga ha la sua versione: e\' quello che legge il sync');
  });

  test('una operazione in outbox per ciascuno, non una sola', () async {
    await todos.addTodo(title: 'Uno');
    await todos.addTodo(title: 'Due');
    final prima = db.outbox.pendingCount();

    final voci = [
      for (final todo in todos.todos) (todo, todo.copyWith(completed: true)),
    ];
    todos.scriviMolti(voci);

    expect(
      db.outbox.pendingCount() - prima,
      2,
      reason: 'il sync viaggia per entita\': una cancellazione multipla deve '
          'accodare una operazione per ciascun todo, non una per il blocco',
    );
  });

  test('cancellare molti, e rimetterli: tornano al loro posto', () async {
    await todos.addTodo(title: 'Uno');
    await todos.addTodo(title: 'Due');
    final vecchi = [...todos.todos];

    todos.scriviMolti([for (final todo in vecchi) (todo, null)]);
    expect(todos.todos, isEmpty);
    expect(db.getTodos(), isEmpty);

    // L'annulla di una cancellazione multipla: stesse righe, versione +2 come nel
    // percorso singolo (`restoreTodo`), e in memoria tornano in coda.
    todos.scriviMolti([for (final todo in vecchi) (todo, todo)], rimetti: true);

    expect(todos.todos.length, 2);
    expect(db.getTodos().length, 2);
    expect(db.getTodos().map((row) => row['version']), everyElement(3));
  });

  test('spostare la data di molti', () async {
    await todos.addTodo(title: 'Uno');
    await todos.addTodo(title: 'Due');
    final quando = DateTime(2026, 10, 5);

    todos.scriviMolti([
      for (final todo in todos.todos) (todo, todo.copyWith(dueDate: quando)),
    ]);

    expect(todos.todos.every((todo) => todo.dueDate == quando), isTrue);
  });

  test('la transazione che fallisce non lascia niente scritto', () {
    expect(
      () => db.runInTransaction(() {
        db.insertTodo(
          Todo(id: 'x', title: 'Rotta', updatedAt: DateTime.now()).toParams(),
        );
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(db.getTodos(), isEmpty);
  });

  test('la selezione: apri, inverti, tutti, chiudi', () {
    final selezione = SelezioneDeiTodo();
    var avvisi = 0;
    selezione.addListener(() => avvisi++);

    expect(selezione.attiva, isFalse);

    selezione.apri('a');
    expect(selezione.attiva, isTrue);
    expect(selezione.quanti, 1);
    expect(selezione.contiene('a'), isTrue);

    selezione.inverti('b');
    selezione.inverti('a');
    expect(selezione.ids, {'b'});

    selezione.tutti(['c', 'd']);
    expect(selezione.quanti, 2);

    selezione.chiudi();
    expect(selezione.attiva, isFalse);
    expect(avvisi, 5);

    // Chiudere una selezione vuota non avvisa nessuno.
    selezione.chiudi();
    expect(avvisi, 5);
  });
}
