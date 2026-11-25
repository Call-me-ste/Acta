import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/database/entity_store.dart';
import 'package:planner/core/database/schema.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:sqlite3/sqlite3.dart';

/// Promemoria, posizione e note: sono **dati come gli altri**, quindi devono
/// fare il giro completo (scrivi → rileggi dal database), entrare nel record di
/// sync, e i database che esistono già devono ricevere le colonne nuove senza
/// perdere righe.
void main() {
  group('evento', () {
    late DatabaseService db;

    setUp(() async {
      db = DatabaseService();
      await db.init(dbPath: ':memory:');
    });

    tearDown(() => db.close());

    test('promemoria, posizione e nota si rileggono dal database', () {
      db.insertEvent(
        Event(
          id: 'e1',
          title: 'Dentista',
          start: DateTime(2026, 9, 14, 9),
          end: DateTime(2026, 9, 14, 10),
          reminderLeads: const [60, 15],
          reminderSound: false,
          location: 'Via Roma 1',
          note: 'portare la tessera',
        ).toParams(),
      );

      final stored = Event.fromRow(db.getEvents().single);
      expect(stored.reminderLeads, [15, 60]);
      expect(stored.reminderSound, isFalse);
      expect(stored.location, 'Via Roma 1');
      expect(stored.note, 'portare la tessera');
    });

    test('si possono azzerare: nessun anticipo, suono ereditato, campi vuoti',
        () {
      db.insertEvent(
        Event(
          id: 'e1',
          title: 'Dentista',
          start: DateTime(2026, 9, 14, 9),
          end: DateTime(2026, 9, 14, 10),
          reminderLeads: const [15],
          reminderSound: true,
          location: 'Via Roma 1',
          note: 'x',
        ).toParams(),
      );

      final updated = Event.fromRow(db.getEvents().single).copyWith(
        reminderLeads: const <int>[],
        reminderSound: null,
        location: '',
        note: '',
      );
      db.updateEvent(updated.toParams());

      final stored = Event.fromRow(db.getEvents().single);
      expect(stored.reminderLeads, isEmpty, reason: 'nessuno, non "default"');
      expect(stored.reminderSound, isNull, reason: 'torna a ereditare');
      expect(stored.location, isEmpty);
      expect(stored.note, isEmpty);
    });

    test('un evento nuovo parte senza promemoria, senza posizione, senza nota',
        () {
      db.insertEvent(
        Event(
          id: 'e1',
          title: 'Dentista',
          start: DateTime(2026, 9, 14, 9),
          end: DateTime(2026, 9, 14, 10),
        ).toParams(),
      );

      final stored = Event.fromRow(db.getEvents().single);
      expect(stored.reminderLeads, isNull, reason: 'null = default globale');
      expect(stored.reminderSound, isNull);
      expect(stored.location, isEmpty);
      expect(stored.note, isEmpty);
    });

    test('copyWith senza argomento non tocca promemoria e posizione', () {
      final original = Event(
        id: 'e1',
        title: 'Dentista',
        start: DateTime(2026, 9, 14, 9),
        end: DateTime(2026, 9, 14, 10),
        reminderLeads: const [15],
        reminderSound: true,
        location: 'Via Roma 1',
        note: 'x',
      );

      final updated = original.copyWith(title: 'Dentista (spostato)');
      expect(updated.reminderLeads, [15]);
      expect(updated.reminderSound, isTrue);
      expect(updated.location, 'Via Roma 1');
      expect(updated.note, 'x');
    });
  });

  group('todo', () {
    late DatabaseService db;

    setUp(() async {
      db = DatabaseService();
      await db.init(dbPath: ':memory:');
    });

    tearDown(() => db.close());

    test('promemoria, posizione e nota si rileggono dal database', () {
      db.insertTodo(
        Todo(
          id: 't1',
          title: 'Spesa',
          dueDate: DateTime(2026, 9, 14),
          reminderLeads: const [1440],
          reminderSound: true,
          location: 'Esselunga',
          note: 'anche il pane',
        ).toParams(),
      );

      final stored = Todo.fromRow(db.getTodos().single);
      expect(stored.reminderLeads, [1440]);
      expect(stored.reminderSound, isTrue);
      expect(stored.location, 'Esselunga');
      expect(stored.note, 'anche il pane');
    });

    test('un todo nuovo resta senza promemoria e senza posizione', () {
      db.insertTodo(const Todo(id: 't1', title: 'Spesa').toParams());

      final stored = Todo.fromRow(db.getTodos().single);
      expect(stored.reminderLeads, isNull);
      expect(stored.reminderSound, isNull);
      expect(stored.location, isEmpty);
      expect(stored.note, isEmpty);
    });

    test('copyWith senza argomento non tocca i campi nuovi', () {
      final updated = const Todo(
        id: 't1',
        title: 'Spesa',
        reminderLeads: [1440],
        reminderSound: true,
        location: 'Esselunga',
        note: 'anche il pane',
      ).copyWith(title: 'Spesa grande');

      expect(updated.reminderLeads, [1440]);
      expect(updated.reminderSound, isTrue);
      expect(updated.location, 'Esselunga');
      expect(updated.note, 'anche il pane');
    });
  });

  group('sync', () {
    test('le colonne nuove sono nella whitelist di entrambe le entità', () {
      for (final entity in ['event', 'todo']) {
        expect(
          EntityStore.columnsFor(entity),
          containsAll(['reminder_leads', 'reminder_sound', 'location', 'note']),
          reason: 'senza whitelist la colonna non viaggia col record',
        );
      }
    });

    test('un record di un client più nuovo non fa fallire il sync', () async {
      final db = DatabaseService();
      await db.init(dbPath: ':memory:');
      addTearDown(db.close);

      // Il client nuovo scrive una colonna che questa versione non conosce:
      // si tiene la riga e si perde solo quel campo, invece di bloccare tutto.
      expect(
        () => db.entities.replace('event', 'e9', {
          'id': 'e9',
          'title': 'Dal futuro',
          'start_time': 1000,
          'end_time': 2000,
          'version': 3,
          'updated_at': 1234,
          'colonna_di_domani': 'valore',
        }),
        returnsNormally,
      );

      final stored = db.entities.allRows('event').single;
      expect(stored['title'], 'Dal futuro');
      expect(stored['version'], 3);
      expect(
        db.instance
            .select('PRAGMA table_info(events)')
            .any((row) => row['name'] == 'colonna_di_domani'),
        isFalse,
        reason: 'la colonna sconosciuta non entra nello schema',
      );
    });

    test('un record senza nessuna colonna conosciuta è un errore vero',
        () async {
      final db = DatabaseService();
      await db.init(dbPath: ':memory:');
      addTearDown(db.close);

      expect(
        () => db.entities.replace('event', 'e9', {'colonna_di_domani': 1}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('migrazione', () {
    test('un database vecchio riceve le colonne nuove, senza perdere righe',
        () {
      final raw = sqlite3.open(':memory:');
      // Lo schema com'era prima: nessuna delle quattro colonne.
      raw.execute('''
        CREATE TABLE events (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT DEFAULT '',
          start_time INTEGER NOT NULL,
          end_time INTEGER NOT NULL,
          all_day INTEGER DEFAULT 0,
          color_index INTEGER DEFAULT 0,
          color_hex TEXT,
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
          color_index INTEGER,
          recurrence_rule TEXT DEFAULT '',
          version INTEGER DEFAULT 1,
          updated_at INTEGER
        )
      ''');
      raw.execute(
        'INSERT INTO events (id, title, start_time, end_time) VALUES (?, ?, ?, ?)',
        ['e1', 'Evento vecchio', 1, 2],
      );
      raw.execute(
        'INSERT INTO todos (id, title) VALUES (?, ?)',
        ['t1', 'Todo vecchio'],
      );

      applySchema(raw);
      applySchema(
          raw); // gira a ogni avvio: la seconda volta non deve fare nulla

      for (final table in ['events', 'todos']) {
        final columns = raw
            .select('PRAGMA table_info($table)')
            .map((row) => row['name'] as String)
            .toList();
        for (final column in [
          'reminder_leads',
          'reminder_sound',
          'location',
          'note',
        ]) {
          expect(
            columns.where((name) => name == column).length,
            1,
            reason: '$table.$column una volta sola',
          );
        }
      }

      // Le righe che c'erano sono ancora lì, coi campi nuovi vuoti.
      expect(Event.fromRow(raw.select('SELECT * FROM events').single).note, '');
      expect(
        Event.fromRow(raw.select('SELECT * FROM events').single).reminderLeads,
        isNull,
      );
      expect(Todo.fromRow(raw.select('SELECT * FROM todos').single).title,
          'Todo vecchio');
      expect(
          Todo.fromRow(raw.select('SELECT * FROM todos').single).location, '');

      raw.dispose();
    });
  });
}
