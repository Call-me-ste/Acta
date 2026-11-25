import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/database/schema.dart';
import 'package:planner/features/todos/todo_hidden.dart';
import 'package:planner/features/todos/todo_provider.dart';

/// Il segno **«via dal calendario»** (`hidden_in_calendar`): il todo resta nella
/// scheda Todo e in agenda, le griglie non lo mostrano piu'.
///
/// Perche' si prova cosi': e' una colonna nuova, quindi il difetto silenzioso e'
/// sempre lo stesso — il segno scritto in memoria e **non** nel database, o nel
/// database e **non** nel record di sync (e allora resta su questo telefono).
/// Qui si guarda la riga vera e la voce di outbox, non lo stato in memoria.
void main() {
  group('migrazione', () {
    test('un database senza la colonna la riceve, e i todo restano visibili',
        () {
      final raw = sqlite3.open(':memory:');
      // Lo schema com'era prima del segno: `todos` senza hidden_in_calendar.
      raw.execute('''
        CREATE TABLE todos (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          completed INTEGER DEFAULT 0,
          priority INTEGER DEFAULT 0,
          due_date INTEGER,
          version INTEGER DEFAULT 1,
          updated_at INTEGER
        )
      ''');
      raw.execute(
        'INSERT INTO todos (id, title, due_date) VALUES (?, ?, ?)',
        ['t1', 'Todo vecchio', 1],
      );

      applySchema(raw);

      final colonne = raw
          .select('PRAGMA table_info(todos)')
          .map((row) => row['name'])
          .toSet();
      expect(colonne, contains('hidden_in_calendar'));

      // Chi aggiorna non vede sparire niente: il default e' «si vede».
      final row = raw.select('SELECT * FROM todos WHERE id = ?', ['t1']).single;
      expect(row['hidden_in_calendar'], 0);
    });
  });

  group('il giro completo', () {
    late DatabaseService db;
    late TodoProvider todos;

    setUp(() async {
      db = DatabaseService();
      await db.init(dbPath: ':memory:');
      todos = TodoProvider(db);
    });

    tearDown(() => db.close);

    final giorno = DateTime(2026, 9, 18);

    test('il segno arriva nel database e nel record di sync', () async {
      await todos.addTodo(title: 'Bolletta', dueDate: giorno);
      final todo = todos.todos.single;
      expect(todo.hiddenInCalendar, isFalse);

      await todos.hideFromCalendar(todo);

      // 1. Nella riga vera (riletta dal database, non dallo stato in memoria).
      final row = db.instance
          .select('SELECT * FROM todos WHERE id = ?', [todo.id]).single;
      expect(row['hidden_in_calendar'], 1);

      // 2. Nel record che viaggia: senza, il segno resterebbe su questo telefono.
      final voce =
          db.outbox.pending().where((row) => row['entity_id'] == todo.id).last;
      expect(voce['operation'], 'upsert');
      expect(
        voce['payload_json'],
        contains('"hidden_in_calendar":1'),
        reason: 'il payload del sync deve portare il segno',
      );
      expect(
        voce['entity_version'],
        greaterThan(todo.version),
        reason: 'il clock avanza: e\' cosi\' che il sync decide chi vince',
      );

      // E in memoria, senza rileggere: la riga sparita dal calendario e' gia'
      // quella nuova.
      expect(todos.todos.single.hiddenInCalendar, isTrue);
    });

    test('l\'annulla toglie il segno, nello stesso giro', () async {
      await todos.addTodo(title: 'Bolletta', dueDate: giorno);
      await todos.hideFromCalendar(todos.todos.single);
      await todos.showInCalendar(todos.todos.single);

      final row = db.instance.select(
          'SELECT * FROM todos WHERE id = ?', [todos.todos.single.id]).single;
      expect(row['hidden_in_calendar'], 0);
      expect(todos.todos.single.hiddenInCalendar, isFalse);
    });

    test('un todo nuovo nasce visibile', () async {
      await todos.addTodo(title: 'Spesa', dueDate: giorno);
      final row = db.instance.select(
          'SELECT * FROM todos WHERE id = ?', [todos.todos.single.id]).single;
      expect(row['hidden_in_calendar'], 0);
    });
  });
}
