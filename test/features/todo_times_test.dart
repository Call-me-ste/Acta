import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/database/entity_store.dart';
import 'package:planner/core/database/schema.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/features/todos/todo_provider.dart';

/// Gli **orari dei todo**: due colonne additive in minuti dalla mezzanotte
/// (`start_time`, `end_time`, nullable).
///
/// Un todo puo' avere solo data, solo inizio, solo fine, o entrambi: la data
/// resta in `due_date`, quindi spostare la scadenza non tocca l'orario.
void main() {
  group('migrazione', () {
    test('un database senza le colonne orario le riceve, senza perdere righe',
        () {
      final raw = sqlite3.open(':memory:');
      // Lo schema com'era prima degli orari: `todos` senza start_time/end_time.
      raw.execute('''
        CREATE TABLE todos (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          completed INTEGER DEFAULT 0,
          priority INTEGER DEFAULT 0,
          due_date INTEGER,
          category TEXT DEFAULT '',
          version INTEGER DEFAULT 1,
          updated_at INTEGER
        )
      ''');
      raw.execute(
        'INSERT INTO todos (id, title, due_date) VALUES (?, ?, ?)',
        ['t1', 'Todo vecchio', 1],
      );

      applySchema(raw);

      Set<Object?> columnsOf(String table) => raw
          .select('PRAGMA table_info($table)')
          .map((row) => row['name'])
          .toSet();

      expect(columnsOf('todos'), contains('start_time'));
      expect(columnsOf('todos'), contains('end_time'));

      // La riga che c'era è ancora lì, e senza orario: non se ne inventa uno.
      final row = raw.select('SELECT * FROM todos WHERE id = ?', ['t1']).single;
      expect(row['title'], 'Todo vecchio');
      expect(row['start_time'], isNull);
      expect(row['end_time'], isNull);

      // E girare due volte non duplica la colonna.
      applySchema(raw);
      expect(
        raw
            .select('PRAGMA table_info(todos)')
            .where((row) => row['name'] == 'start_time')
            .length,
        1,
      );
    });
  });

  group('sync', () {
    test('ogni colonna dei todo e\' nella whitelist di EntityStore', () async {
      final db = DatabaseService();
      await db.init(dbPath: ':memory:');
      addTearDown(db.close);

      final reali = {
        for (final row in db.instance.select('PRAGMA table_info(todos)'))
          row['name'] as String,
      };
      // `category` e' la vecchia categoria singola (migrata in `category_ids`):
      // sta in tabella per la conversione, ma non viaggia.
      reali.remove('category');

      expect(
        reali.difference(EntityStore.columnsFor('todo')),
        isEmpty,
        reason:
            'una colonna fuori dalla whitelist non viaggia fra device, e il '
            'difetto e\' silenzioso: il dato resterebbe solo su questo telefono',
      );
    });
  });

  group('orari', () {
    late DatabaseService db;
    late TodoProvider todos;

    setUp(() async {
      db = DatabaseService();
      await db.init(dbPath: ':memory:');
      todos = TodoProvider(db);
    });

    tearDown(() => db.close());

    final giorno = DateTime(2026, 9, 18);

    test('round-trip: solo inizio, solo fine, entrambi, nessuno', () async {
      await todos.addTodo(
          title: 'Solo inizio', dueDate: giorno, startMinutes: 8 * 60);
      await todos.addTodo(
          title: 'Solo fine', dueDate: giorno, endMinutes: 18 * 60);
      await todos.addTodo(
        title: 'Entrambi',
        dueDate: giorno,
        startMinutes: 8 * 60,
        endMinutes: 9 * 60,
      );
      await todos.addTodo(title: 'Nessuno', dueDate: giorno);

      // Rileggo dal database come farebbe un avvio nuovo: e' li' che una colonna
      // dimenticata nell'INSERT o nel fromRow si vedrebbe.
      final riletti = TodoProvider(db);
      Todo cerca(String titolo) =>
          riletti.todos.firstWhere((todo) => todo.title == titolo);

      expect(cerca('Solo inizio').startMinutes, 480);
      expect(cerca('Solo inizio').endMinutes, isNull);
      expect(cerca('Solo fine').startMinutes, isNull);
      expect(cerca('Solo fine').endMinutes, 1080);
      expect(cerca('Entrambi').startMinutes, 480);
      expect(cerca('Entrambi').endMinutes, 540);
      expect(cerca('Nessuno').startMinutes, isNull);
      expect(cerca('Nessuno').endMinutes, isNull);
    });

    test('chi ha un orario sta davanti, e in ordine d\'ora', () async {
      // La priorita' piu' alta di tutte ce l'ha quello **senza** orario: se
      // l'ordine lo mettesse davanti, la regola richiesta non varrebbe.
      await todos.addTodo(title: 'Senza orario', priority: 3, dueDate: giorno);
      await todos.addTodo(
          title: 'Alle 12', dueDate: giorno, startMinutes: 12 * 60);
      await todos.addTodo(
          title: 'Alle 8', dueDate: giorno, startMinutes: 8 * 60);

      expect(
        [for (final todo in todos.todos) todo.title],
        ['Alle 8', 'Alle 12', 'Senza orario'],
      );
    });

    test('anche un solo orario di fine conta per l\'ordine', () async {
      await todos.addTodo(title: 'Senza orario', dueDate: giorno);
      await todos.addTodo(
          title: 'Entro le 18', dueDate: giorno, endMinutes: 18 * 60);

      expect(
        [for (final todo in todos.todos) todo.title],
        ['Entro le 18', 'Senza orario'],
      );
    });
  });
}
