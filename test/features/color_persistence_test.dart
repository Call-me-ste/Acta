import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/database/entity_store.dart';
import 'package:planner/core/database/schema.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Il colore è un dato come gli altri: deve **sopravvivere al giro completo**
/// (scrivi → rileggi dal database), entrare nel record di sync, e i database che
/// esistono già devono ricevere le colonne nuove senza perdere niente.
void main() {
  group('colore sull\'evento', () {
    late DatabaseService db;
    late EventProvider events;

    setUp(() async {
      db = DatabaseService();
      await db.init(dbPath: ':memory:');
      events = EventProvider(db);
    });

    tearDown(() => db.close());

    test('un colore libero si rilegge dal database', () async {
      await events.addEvent(
        title: 'Palestra',
        start: DateTime(2026, 9, 14, 18),
        end: DateTime(2026, 9, 14, 19),
        colorHex: '#ff69b4',
      );

      final stored = db.getEvents().map(Event.fromRow).single;
      expect(stored.colorHex, '#ff69b4');
      expect(stored.colorIndex, 0, reason: 'l\'indice resta il default');
    });

    test('l\'hex viaggia anche nel record di sync', () async {
      await events.addEvent(
        title: 'Palestra',
        start: DateTime(2026, 9, 14, 18),
        end: DateTime(2026, 9, 14, 19),
        colorHex: '#ff69b4',
      );

      final payload =
          jsonDecode(db.outbox.pending().single['payload_json'] as String)
              as Map<String, dynamic>;
      expect(payload['color_hex'], '#ff69b4');
      expect(EntityStore.columnsFor('event'), contains('color_hex'));
    });

    test('si può togliere il colore libero e tornare alla palette', () async {
      await events.addEvent(
        title: 'Palestra',
        start: DateTime(2026, 9, 14, 18),
        end: DateTime(2026, 9, 14, 19),
        colorHex: '#ff69b4',
      );

      final stored = events.events.single;
      await events.updateEvent(stored.copyWith(colorHex: null));

      expect(events.events.single.colorHex, isNull);
      expect(db.getEvents().map(Event.fromRow).single.colorHex, isNull);
    });

    test('copyWith senza argomento non tocca il colore', () async {
      await events.addEvent(
        title: 'Palestra',
        start: DateTime(2026, 9, 14, 18),
        end: DateTime(2026, 9, 14, 19),
        colorHex: '#ff69b4',
      );

      final updated = events.events.single.copyWith(title: 'Nuovo titolo');
      expect(updated.colorHex, '#ff69b4');
    });
  });

  group('colore sul todo', () {
    late DatabaseService db;
    late TodoProvider todos;

    setUp(() async {
      db = DatabaseService();
      await db.init(dbPath: ':memory:');
      todos = TodoProvider(db);
    });

    tearDown(() => db.close());

    test('un todo senza colore resta neutro', () async {
      await todos.addTodo(title: 'Spesa');
      expect(todos.todos.single.colorIndex, isNull);
    });

    test('il colore scelto si rilegge dal database', () async {
      await todos.addTodo(title: 'Spesa', colorIndex: 3);

      final stored = db.getTodos().map(Todo.fromRow).single;
      expect(stored.colorIndex, 3);
      expect(EntityStore.columnsFor('todo'), contains('color_index'));
    });

    test('si può togliere il colore', () async {
      await todos.addTodo(title: 'Spesa', colorIndex: 3);
      await todos.updateTodo(todos.todos.single.copyWith(colorIndex: null));
      expect(todos.todos.single.colorIndex, isNull);
    });
  });

  group('migrazione', () {
    test('un database senza le colonne colore le riceve, senza perdere righe',
        () {
      final raw = sqlite3.open(':memory:');
      // Lo schema com'era prima della Fase 1: events senza `color_hex`,
      // todos senza `color_index`.
      raw.execute('''
        CREATE TABLE events (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT DEFAULT '',
          start_time INTEGER NOT NULL,
          end_time INTEGER NOT NULL,
          all_day INTEGER DEFAULT 0,
          color_index INTEGER DEFAULT 0,
          recurrence_rule TEXT DEFAULT '',
          version INTEGER DEFAULT 1,
          updated_at INTEGER
        )
      ''');
      raw.execute('''
        CREATE TABLE todos (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          completed INTEGER DEFAULT 0,
          priority INTEGER DEFAULT 0,
          due_date INTEGER,
          category TEXT DEFAULT '',
          recurrence_rule TEXT DEFAULT '',
          version INTEGER DEFAULT 1,
          updated_at INTEGER
        )
      ''');
      raw.execute(
        'INSERT INTO events (id, title, start_time, end_time) VALUES (?, ?, ?, ?)',
        ['e1', 'Evento vecchio', 1, 2],
      );

      applySchema(raw);

      Set<Object?> columnsOf(String table) => raw
          .select('PRAGMA table_info($table)')
          .map((row) => row['name'])
          .toSet();

      expect(columnsOf('events'), contains('color_hex'));
      expect(columnsOf('todos'), contains('color_index'));
      // La riga che c'era è ancora lì, col colore vuoto.
      final row =
          raw.select('SELECT * FROM events WHERE id = ?', ['e1']).single;
      expect(row['title'], 'Evento vecchio');
      expect(row['color_hex'], isNull);

      // E girare due volte non duplica la colonna.
      applySchema(raw);
      expect(
        raw
            .select('PRAGMA table_info(events)')
            .where((row) => row['name'] == 'color_hex')
            .length,
        1,
      );

      raw.dispose();
    });
  });
}
