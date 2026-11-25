import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/database/schema.dart';
import 'package:sqlite3/sqlite3.dart';

/// Exercises every public query so a column that does not exist in the schema
/// fails here instead of at runtime. `getTodos()` shipped an
/// `ORDER BY created_at` against a table without that column: `flutter analyze`
/// was clean and the Todo tab threw `SqliteException: no such column` on open.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  test('every read path runs against the real schema', () {
    expect(db.getEvents(), isEmpty);
    expect(db.getEventsBetween(DateTime(2026, 9, 13), DateTime(2026, 9, 14)),
        isEmpty);
    expect(db.getTodos(), isEmpty);
    expect(db.notes.all(), isEmpty);
    expect(db.notes.search('x'), isEmpty);
    expect(db.outbox.pending(), isEmpty);
  });

  test(
      'events round-trip: la lettura è grezza, la conversione vive nel modello',
      () {
    db.insertEvent({
      'id': 'e1',
      'title': 'Dentista',
      'start_time': 1000,
      'end_time': 2000,
    });

    final loaded = db.getEvents().single;
    expect(loaded['title'], 'Dentista');
    expect(loaded['all_day'], 0); // int, non bool: il tipo lo dà Event.fromRow
    expect(loaded['description'], ''); // default applicato dallo schema

    db.updateEvent({
      'id': 'e1',
      'title': 'Dentista (spostato)',
      'start_time': 1000,
      'end_time': 2000,
    });
    expect(db.getEvents().single['title'], 'Dentista (spostato)');

    db.deleteEvent('e1');
    expect(db.getEvents(), isEmpty);
  });

  test('getEventsBetween restituisce solo gli eventi di quella finestra', () {
    db.insertEvent({
      'id': 'a',
      'title': 'oggi',
      'start_time': DateTime(2026, 9, 13, 9).millisecondsSinceEpoch,
      'end_time': DateTime(2026, 9, 13, 10).millisecondsSinceEpoch,
    });
    db.insertEvent({
      'id': 'b',
      'title': 'domani',
      'start_time': DateTime(2026, 9, 14, 9).millisecondsSinceEpoch,
      'end_time': DateTime(2026, 9, 14, 10).millisecondsSinceEpoch,
    });

    expect(
      db
          .getEventsBetween(DateTime(2026, 9, 13), DateTime(2026, 9, 14))
          .map((r) => r['id']),
      ['a'],
    );
    expect(
      db
          .getEventsBetween(DateTime(2026, 9, 14), DateTime(2026, 9, 15))
          .map((r) => r['id']),
      ['b'],
    );
    expect(db.getEventsBetween(DateTime(2026, 9, 15), DateTime(2026, 9, 16)),
        isEmpty);
  });

  test('todos round-trip and come back ordered by priority', () {
    db.insertTodo({'id': 't1', 'title': 'bassa', 'priority': 0});
    db.insertTodo({'id': 't2', 'title': 'alta', 'priority': 3});

    final todos = db.getTodos();
    expect(todos.map((t) => t['id']), ['t2', 't1']);
    // int, non bool: la conversione a `bool` la fa Todo.fromRow.
    expect(todos.first['completed'], 0);
    expect(todos.first['due_date'], isNull);

    db.updateTodo({
      'id': 't1',
      'title': 'fatta',
      'completed': 1,
      'priority': 0,
      'due_date': null,
      'category': '',
    });
    final updated = db.getTodos().firstWhere((t) => t['id'] == 't1');
    expect(updated['completed'], 1);
    expect(updated['title'], 'fatta');

    db.deleteTodo('t1');
    expect(db.getTodos().map((t) => t['id']), ['t2']);
  });

  test('notes search and round-trip', () {
    db.notes.insert({'id': 'n1', 'title': 'Spesa', 'content': 'latte e pane'});
    db.notes.insert({'id': 'n2', 'title': 'Idee', 'content': 'app planner'});

    expect(db.notes.all(), hasLength(2));
    expect(db.notes.search('latte').single['id'], 'n1');
    expect(db.notes.search('planner').single['id'], 'n2');

    db.notes.update({'id': 'n1', 'title': 'Spesa', 'content': 'solo pane'});
    expect(db.notes.search('latte'), isEmpty);

    db.notes.delete('n2');
    expect(db.notes.all().single['id'], 'n1');
  });

  test("la coda dell'outbox resta finché non è sincronizzata", () {
    db.outbox.enqueue(
      operationId: 'op1',
      entity: 'event',
      entityId: 'e1',
      operation: 'upsert',
      version: 1,
      updatedAt: 1000,
      payload: const {'id': 'e1'},
    );

    expect(db.outbox.pending().single['operation_id'], 'op1');
    expect(db.outbox.pendingCount(), 1);

    db.outbox.markSynced(['op1']);
    expect(db.outbox.pending(), isEmpty);
    expect(db.outbox.pendingCount(), 0);
  });

  test('la compattazione tiene solo l\'ultima operazione per elemento', () {
    // Lo stesso elemento scritto cinque volte: al sync interessa **dove e'
    // arrivato**, non da dove e' passato.
    for (var i = 1; i <= 5; i++) {
      db.outbox.enqueue(
        operationId: 'op$i',
        entity: 'todo',
        entityId: 't1',
        operation: 'upsert',
        version: i,
        updatedAt: 1000 * i,
        payload: {'id': 't1', 'title': 'giro $i'},
      );
    }
    db.outbox.enqueue(
      operationId: 'altro',
      entity: 'event',
      entityId: 'e1',
      operation: 'upsert',
      version: 1,
      updatedAt: 500,
      payload: const {'id': 'e1'},
    );

    // Il clock che il sync legge **prima** della compattazione.
    final clockPrima = db.outbox.pendingClock('todo', 't1');

    expect(db.outbox.compact(), 4, reason: 'quattro giri intermedi');

    expect(db.outbox.pendingCount(), 2);
    final rimaste = db.outbox.pending().map((riga) => riga['operation_id']);
    expect(rimaste, containsAll(['op5', 'altro']));
    // Il clock non cambia: e' quello che il sync confronta fra due dispositivi.
    expect(db.outbox.pendingClock('todo', 't1'), clockPrima);
    expect(db.outbox.pendingClock('todo', 't1'), (5, 5000));
    // E il payload dell'ultima resta intero: e' quello che partira'.
    final ultima =
        db.outbox.pending().firstWhere((r) => r['operation_id'] == 'op5');
    expect(ultima['payload_json'], contains('giro 5'));
  });

  test('la compattazione lascia in pace le operazioni mai partite', () {
    for (var i = 1; i <= 3; i++) {
      db.outbox.enqueue(
        operationId: 'op$i',
        entity: 'todo',
        entityId: 't1',
        operation: 'upsert',
        version: i,
        updatedAt: i,
        payload: const {},
      );
    }

    db.outbox.compact();

    // Una sola riga: l'ultima. Buttare **anche** quella vorrebbe dire perdere
    // una modifica che non e' mai arrivata da nessuna parte.
    expect(db.outbox.pending(), hasLength(1));
    expect(db.outbox.pending().single['operation_id'], 'op3');
  });

  test('le righe sincronizzate vecchie si cancellano, le recenti no', () {
    db.outbox.enqueue(
      operationId: 'vecchia',
      entity: 'todo',
      entityId: 't1',
      operation: 'upsert',
      version: 1,
      updatedAt: 1,
      payload: const {},
    );
    db.outbox.enqueue(
      operationId: 'recente',
      entity: 'todo',
      entityId: 't1',
      operation: 'upsert',
      version: 2,
      updatedAt: 2,
      payload: const {},
    );
    db.outbox.markSynced(['vecchia', 'recente']);
    // La vecchia si finge partita due mesi fa: `enqueue` data sempre adesso.
    final dueMesi = DateTime.now()
        .subtract(const Duration(days: 60))
        .millisecondsSinceEpoch;
    db.instance.execute(
      'UPDATE outbox SET created_at = ? WHERE operation_id = ?',
      [dueMesi, 'vecchia'],
    );

    expect(db.outbox.compact(), 1);

    final rimaste = db.outbox.pending().map((riga) => riga['operation_id']);
    expect(rimaste, isEmpty, reason: 'erano tutte sincronizzate');
  });

  test('runInTransaction non lascia metà scrittura', () {
    expect(
      () => db.runInTransaction(() {
        db.insertEvent({
          'id': 'e9',
          'title': 'Boom',
          'start_time': 1,
          'end_time': 2,
        });
        throw StateError('errore simulato a metà transazione');
      }),
      throwsStateError,
    );

    // Il rollback ha rimesso tutto a posto: né la riga né l'outbox.
    expect(db.getEvents(), isEmpty);
    expect(db.outbox.pending(), isEmpty);
  });

  test('gli indici delle finestre ci sono, quello diventato inutile no', () {
    final nomi = db.instance
        .select("SELECT name FROM sqlite_master WHERE type = 'index'")
        .map((row) => row['name'] as String)
        .toSet();

    // `todos(due_date)`: la griglia del mese e la scheda Todo chiedono i todo di
    // una finestra di giorni.
    expect(nomi, contains('idx_todos_due_date'));
    // Composito: copre sia le conferme di un elemento sia la singola occorrenza.
    expect(nomi, contains('idx_occurrence_item_day'));
    // Il vecchio indice su `item_id` da solo è coperto dal composito e si paga a
    // ogni scrittura: non deve tornare.
    expect(nomi, isNot(contains('idx_occurrence_item')));
  });

  test('su file il journal è WAL: scrivere non blocca leggere', () async {
    final cartella = Directory.systemTemp.createTempSync('planner-db-wal');
    addTearDown(() => cartella.deleteSync(recursive: true));

    final suFile = DatabaseService();
    await suFile.init(dbPath: p.join(cartella.path, 'planner.db'));
    addTearDown(suFile.close);

    expect(
      suFile.instance.select('PRAGMA journal_mode').single['journal_mode'],
      'wal',
    );
  });

  test('la versione dello schema si scrive e si rilegge dal file', () {
    final fresco = sqlite3.openInMemory();
    addTearDown(fresco.dispose);

    // Un file appena creato: nessuna versione e nessuno schema. I due casi che
    // hanno entrambi `user_version = 0` si distinguono da quello che c'e' dentro.
    expect(readSchemaVersion(fresco), 0);
    expect(hasExistingSchema(fresco), isFalse);

    applySchema(fresco);

    expect(readSchemaVersion(fresco), schemaVersion);
    expect(hasExistingSchema(fresco), isTrue);
  });

  test('un percorso nuovo nasce gia\' alla versione corrente', () {
    expect(db.schemaVersionAtOpen, 0);
    expect(db.currentSchemaVersion, schemaVersion);
  });

  test('un database esistente senza versione viene portato a quella corrente',
      () async {
    final cartella = Directory.systemTemp.createTempSync('planner-db-vecchio');
    addTearDown(() => cartella.deleteSync(recursive: true));
    final percorso = p.join(cartella.path, 'planner.db');

    // «Vecchio» quanto basta per essere il caso vero: schema completo (come lo
    // creava la versione precedente) ma **senza** la versione scritta, e con
    // dentro un dato. Inventare a mano uno schema vecchio proverebbe solo che
    // so scrivere una tabella.
    final prima = DatabaseService();
    await prima.init(dbPath: percorso);
    prima.insertEvent({
      'id': 'e-vecchio',
      'title': 'Dato di prima',
      'start_time': 1000,
      'end_time': 2000,
    });
    prima.instance.execute('PRAGMA user_version = 0');
    prima.close();

    final dopo = DatabaseService();
    await dopo.init(dbPath: percorso);
    addTearDown(dopo.close);

    expect(dopo.schemaVersionAtOpen, 0, reason: 'da dove si veniva');
    expect(dopo.currentSchemaVersion, schemaVersion, reason: 'dove si e\'');
    expect(dopo.getEvents().single['title'], 'Dato di prima',
        reason: 'migrare non tocca i dati');
  });

  test('la seconda apertura non ha piu\' niente da migrare', () async {
    final cartella = Directory.systemTemp.createTempSync('planner-db-due');
    addTearDown(() => cartella.deleteSync(recursive: true));
    final percorso = p.join(cartella.path, 'planner.db');

    final prima = DatabaseService();
    await prima.init(dbPath: percorso);
    prima.close();

    final seconda = DatabaseService();
    await seconda.init(dbPath: percorso);
    addTearDown(seconda.close);

    // E' il segnale che la copia pre-migrazione usera' per non farne una a ogni
    // avvio: se questa fosse 0, l'app copierebbe il database ogni volta.
    expect(seconda.schemaVersionAtOpen, schemaVersion);
  });

  group('il gancio prima di migrare', () {
    /// Un database con lo schema di **prima** (quello di un'app installata da
    /// mesi) e un dato dentro.
    Future<String> databaseVecchio(Directory cartella) async {
      final percorso = p.join(cartella.path, 'planner.db');
      final vecchio = DatabaseService();
      await vecchio.init(dbPath: percorso);
      vecchio.insertEvent({
        'id': 'e1',
        'title': 'Da non perdere',
        'start_time': 1000,
        'end_time': 2000,
      });
      vecchio.instance.execute('PRAGMA user_version = 0');
      vecchio.close();
      return percorso;
    }

    test('si chiama su un database che esiste, e con la versione di partenza',
        () async {
      final cartella = Directory.systemTemp.createTempSync('planner-hook');
      addTearDown(() => cartella.deleteSync(recursive: true));
      final percorso = await databaseVecchio(cartella);

      final chiamate = <int>[];
      final db2 = DatabaseService();
      await db2.init(
        dbPath: percorso,
        primaDiMigrare: (daVersione) async {
          // La proprieta' che conta: al momento della chiamata lo schema e'
          // **ancora quello di prima**. Se il gancio scattasse dopo
          // `applySchema`, la copia fotograferebbe il database gia' migrato —
          // cioe' esattamente quello che non serve.
          expect(readSchemaVersion(db2.instance), daVersione);
          expect(daVersione, lessThan(schemaVersion));
          chiamate.add(daVersione);
        },
      );
      addTearDown(db2.close);

      expect(chiamate, [0]);
      expect(db2.currentSchemaVersion, schemaVersion);
      expect(db2.getEvents().single['title'], 'Da non perdere');
    });

    test('una copia fallita blocca la migrazione e permette di riprovare',
        () async {
      final cartella =
          Directory.systemTemp.createTempSync('planner-migration-guard');
      addTearDown(() => cartella.deleteSync(recursive: true));
      final percorso = await databaseVecchio(cartella);
      final database = DatabaseService();
      await expectLater(
          database.init(
            dbPath: percorso,
            appVersion: '1.0.0+2',
            primaDiAggiornare: (_, __) async => false,
          ),
          throwsA(isA<MigrationBackupRequired>()));
      final retry = DatabaseService();
      await retry.init(
        dbPath: percorso,
        appVersion: '1.0.0+2',
        primaDiAggiornare: (schema, _) async {
          expect(schema, 0);
          return true;
        },
      );
      addTearDown(retry.close);
      expect(retry.currentSchemaVersion, schemaVersion);
      expect(retry.getEvents().single['title'], 'Da non perdere');
    });

    test('un aggiornamento dell\'app fa scattare il gancio una volta sola',
        () async {
      final cartella = Directory.systemTemp.createTempSync('planner-versioni');
      addTearDown(() => cartella.deleteSync(recursive: true));
      final percorso = p.join(cartella.path, 'planner.db');

      final vecchio = DatabaseService();
      await vecchio.init(dbPath: percorso, appVersion: '1.0.0+1');
      vecchio.insertEvent({
        'id': 'e1',
        'title': 'Da non perdere',
        'start_time': 1000,
        'end_time': 2000,
      });
      vecchio.close();

      final chiamate = <String?>[];
      final nuovo = DatabaseService();
      await nuovo.init(
        dbPath: percorso,
        appVersion: '1.0.0+2',
        primaDiAggiornare: (daVersione, daAppVersion) async {
          chiamate.add(daAppVersion);
          return true;
        },
      );
      addTearDown(nuovo.close);
      expect(chiamate, ['1.0.0+1']);
      expect(nuovo.getEvents().single['title'], 'Da non perdere');

      // La versione e' stata scritta solo dopo la copia riuscita: la seconda
      // apertura non richiede un'altra copia.
      nuovo.close();
      final terza = DatabaseService();
      await terza.init(
        dbPath: percorso,
        appVersion: '1.0.0+2',
        primaDiAggiornare: (_, __) async {
          chiamate.add('non doveva');
          return true;
        },
      );
      addTearDown(terza.close);
      expect(chiamate, ['1.0.0+1']);
    });

    test('se la copia fallisce, la versione non viene scritta', () async {
      final cartella =
          Directory.systemTemp.createTempSync('planner-copia-fail');
      addTearDown(() => cartella.deleteSync(recursive: true));
      final percorso = p.join(cartella.path, 'planner.db');

      final prima = DatabaseService();
      await prima.init(dbPath: percorso, appVersion: '1.0.0+1');
      prima.close();

      final chiamate = <String?>[];
      final seconda = DatabaseService();
      await seconda.init(
        dbPath: percorso,
        appVersion: '1.0.0+2',
        primaDiAggiornare: (_, daAppVersion) async {
          chiamate.add(daAppVersion);
          return false;
        },
      );
      seconda.close();

      final terza = DatabaseService();
      await terza.init(
        dbPath: percorso,
        appVersion: '1.0.0+2',
        primaDiAggiornare: (_, daAppVersion) async {
          chiamate.add(daAppVersion);
          return true;
        },
      );
      addTearDown(terza.close);

      expect(chiamate, ['1.0.0+1', '1.0.0+1'],
          reason: 'il fallimento non deve far dimenticare la copia');
    });

    test('un database di una versione piu\' nuova non si apre', () async {
      final cartella = Directory.systemTemp.createTempSync('planner-db-futuro');
      addTearDown(() => cartella.deleteSync(recursive: true));
      final percorso = p.join(cartella.path, 'planner.db');

      final prima = DatabaseService();
      await prima.init(dbPath: percorso);
      prima.insertEvent({
        'id': 'e1',
        'title': 'Dati del futuro',
        'start_time': 1000,
        'end_time': 2000,
      });
      prima.instance.execute('PRAGMA user_version = ${schemaVersion + 1}');
      prima.close();

      final vecchia = DatabaseService();
      await expectLater(
        vecchia.init(dbPath: percorso),
        throwsA(isA<StateError>()),
      );

      // Il file e il dato sono ancora li': rifiutare di aprirlo non cancella
      // niente, lascia solo la possibilita' di reinstallare la build giusta.
      final controllo = sqlite3.open(percorso);
      addTearDown(controllo.dispose);
      expect(
        controllo.select('SELECT title FROM events').single['title'],
        'Dati del futuro',
      );
    });

    test('non si chiama su un percorso nuovo, ne\' su uno gia\' migrato',
        () async {
      final cartella = Directory.systemTemp.createTempSync('planner-hook-2');
      addTearDown(() => cartella.deleteSync(recursive: true));
      final percorso = p.join(cartella.path, 'planner.db');

      final chiamate = <int>[];
      Future<void> apri() async {
        final servizio = DatabaseService();
        await servizio.init(
          dbPath: percorso,
          primaDiMigrare: (daVersione) async => chiamate.add(daVersione),
        );
        servizio.close();
      }

      await apri(); // file appena creato: niente da copiare
      await apri(); // gia' alla versione corrente: niente da copiare

      expect(chiamate, isEmpty);
    });
  });
}
