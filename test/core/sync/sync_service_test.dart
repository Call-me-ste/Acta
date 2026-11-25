import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/sync/drive_failure.dart';
import 'package:planner/core/sync/encrypted_sync_gateway.dart';
import 'package:planner/core/sync/folder_sync_gateway.dart';
import 'package:planner/core/sync/shard_codec.dart';
import 'package:planner/core/sync/shard_writer.dart';
import 'package:planner/core/sync/sync_gateway.dart';
import 'package:planner/core/sync/sync_manifest.dart';
import 'package:planner/core/sync/sync_record.dart';
import 'package:planner/core/sync/sync_service.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/domain/note.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/features/todos/todo_provider.dart';

/// Conta quanto si scrive davvero: è la misura che dimostra che un sync non
/// ricarica l'archivio intero.
class CountingGateway implements SyncGateway {
  CountingGateway(this._inner);

  final SyncGateway _inner;
  int bytesWritten = 0;
  int writes = 0;
  int? omitWriteNumber;
  int? interruptAfterWriteNumber;
  DriveFailure? writeFailure;
  Future<void> Function()? beforeChangeWrite;

  void reset() {
    bytesWritten = 0;
    writes = 0;
  }

  @override
  Future<List<String>> list(String prefix) => _inner.list(prefix);

  @override
  Future<List<int>?> read(String path) => _inner.read(path);

  @override
  Future<void> write(String path, List<int> bytes) async {
    bytesWritten += bytes.length;
    writes += 1;
    if (path.startsWith(EncryptedSyncGateway.changesPrefix)) {
      await beforeChangeWrite?.call();
      if (writeFailure case final failure?) throw failure;
    }
    if (writes == omitWriteNumber) return;
    await _inner.write(path, bytes);
    if (writes == interruptAfterWriteNumber) {
      throw const SocketException('Connection lost after remote write');
    }
  }

  @override
  Future<void> delete(String path) => _inner.delete(path);
}

void main() {
  late Directory tempDir;
  late DatabaseService db;
  late FolderSyncGateway folder;
  late CountingGateway gateway;
  late SyncService sync;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('planner-sync-test');
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    folder = FolderSyncGateway(tempDir.path);
    gateway = CountingGateway(folder);
    sync = SyncService(db)..useGateway(gateway);
  });

  tearDown(() {
    db.close();
    tempDir.deleteSync(recursive: true);
  });

  /// Riempie database **e** outbox come farebbe l'app, ma senza passare dai
  /// provider: 3000 giri di `notifyListeners` non servono a nessun test.
  void seedTodos(int count) {
    db.runInTransaction(() {
      for (var index = 0; index < count; index++) {
        final id = 'todo-$index';
        final updatedAt = 1789000000000 + index;
        final params = <String, Object?>{
          'id': id,
          'title': 'Todo $index',
          'completed': 0,
          'priority': 0,
          'due_date': null,
          'category': '',
          'version': 1,
          'updated_at': updatedAt,
        };
        db.insertTodo(params);
        db.outbox.enqueue(
          operationId: 'op-$index',
          entity: 'todo',
          entityId: id,
          operation: 'upsert',
          version: 1,
          updatedAt: updatedAt,
          payload: params,
        );
      }
    });
  }

  Future<int> archiveBytes() async {
    var total = 0;
    for (final path in await folder.list('')) {
      total += (await folder.read(path))!.length;
    }
    return total;
  }

  test('keeps the queue until the encrypted change can be read back', () async {
    seedTodos(1);
    final encrypted =
        EncryptedSyncGateway(gateway, SecretKey(List.filled(32, 7)));
    sync.useGateway(encrypted, accountKey: 'test-account');
    gateway.omitWriteNumber = 1;

    await expectLater(sync.fullSync(), throwsStateError);
    expect(sync.pendingCount, 1);
    expect(sync.lastSyncTime, isNull);

    await sync.fullSync();
    expect(sync.pendingCount, 0);
    expect(sync.remoteShardCount, 1);
    final restored = SyncService(db)
      ..useGateway(encrypted, accountKey: 'test-account');
    expect(restored.lastSyncTime, sync.lastSyncTime);
    expect(restored.remoteShardCount, 1);
  });

  test('a restarted replica retries unconfirmed batches without duplicates',
      () async {
    const count = 2 * ShardCodec.maxRecordsPerShard + 37;
    seedTodos(count);
    final key = SecretKey(List.filled(32, 7));
    final encrypted = EncryptedSyncGateway(gateway, key);
    sync.useGateway(encrypted, accountKey: 'test-account');
    gateway.interruptAfterWriteNumber = 2;

    await expectLater(sync.fullSync(), throwsA(isA<SocketException>()));
    expect(sync.pendingCount, count - ShardCodec.maxRecordsPerShard);
    expect(await encrypted.listChanges(), hasLength(2));
    expect(sync.lastSyncTime, isNull);

    final restarted = SyncService(db)
      ..useGateway(encrypted, accountKey: 'test-account');
    await restarted.fullSync();
    expect(restarted.pendingCount, 0);
    expect(await encrypted.listChanges(), hasLength(3));

    final fresh = DatabaseService();
    await fresh.init(dbPath: ':memory:');
    addTearDown(fresh.close);
    final reader = SyncService(fresh)
      ..useGateway(EncryptedSyncGateway(folder, key),
          accountKey: 'test-account');
    expect(await reader.fullSync(), count);
    expect(
      fresh.instance.select('SELECT id, title FROM todos').map(
            (row) => (row['id'], row['title']),
          ),
      unorderedEquals([
        for (var index = 0; index < count; index++)
          ('todo-$index', 'Todo $index')
      ]),
    );
    expect(await reader.fullSync(), 0);
  });

  test('Drive quota waits locally and retries without advancing the receipt',
      () async {
    final encrypted =
        EncryptedSyncGateway(gateway, SecretKey(List.filled(32, 7)));
    sync.useGateway(encrypted, accountKey: 'test-account');
    await sync.fullSync();
    final receipt = sync.lastSyncTime;
    seedTodos(1);
    gateway.writeFailure = const DriveFailure(DriveFailureKind.storageFull);
    await expectLater(sync.fullSync(), throwsA(isA<DriveFailure>()));
    expect(sync.pendingCount, 1);
    expect(sync.lastSyncTime, receipt);
    expect(await encrypted.listChanges(), isEmpty);
    expect(db.instance.select('SELECT title FROM todos').single['title'],
        'Todo 0');

    gateway.writeFailure = null;
    await sync.fullSync();
    expect(sync.pendingCount, 0);
    expect(await encrypted.listChanges(), hasLength(1));
  });

  test(
      'concurrent devices publish independent changes beside the legacy archive',
      () async {
    final other = DatabaseService();
    final fresh = DatabaseService();
    await other.init(dbPath: ':memory:');
    await fresh.init(dbPath: ':memory:');
    addTearDown(other.close);
    addTearDown(fresh.close);

    final key = SecretKey(List.filled(32, 7));
    final first = EncryptedSyncGateway(gateway, key);
    final second = EncryptedSyncGateway(folder, key);
    final ready = Completer<void>();
    final resume = Completer<void>();

    await TodoProvider(db).addTodo(title: 'Archivio precedente');
    await sync.exportTo(first);
    await TodoProvider(db).addTodo(title: 'Modifica A');
    await TodoProvider(other).addTodo(title: 'Modifica B');
    gateway.beforeChangeWrite = () {
      if (!ready.isCompleted) ready.complete();
      return resume.future;
    };

    sync.useGateway(first);
    final syncB = SyncService(other)..useGateway(second);
    final sending = sync.fullSync();
    await ready.future;
    try {
      await syncB.fullSync();
    } finally {
      resume.complete();
      await sending;
    }

    final reader = SyncService(fresh)..useGateway(second);
    expect(await reader.fullSync(), 3);
    expect(
        fresh.instance.select('SELECT title FROM todos').map((r) => r['title']),
        unorderedEquals(['Archivio precedente', 'Modifica A', 'Modifica B']));
    expect(sync.pendingCount, 0);
    expect(syncB.pendingCount, 0);
    expect(await reader.fullSync(), 0);
  });

  /// "Dispositivo nuovo": dimentica quali shard ha già applicato. Serve nei casi
  /// di conflitto, dove si importano archivi diversi che usano lo stesso
  /// percorso relativo.
  void forgetSyncState() => db.instance.execute('DELETE FROM sync_meta');

  SyncRecord todoRecord({
    String id = 't1',
    int version = 1,
    required DateTime updatedAt,
    String title = 'remoto',
    SyncOperation operation = SyncOperation.upsert,
  }) {
    return SyncRecord(
      entity: 'todo',
      id: id,
      operation: operation,
      version: version,
      updatedAt: updatedAt,
      data: operation == SyncOperation.upsert
          ? {
              'id': id,
              'title': title,
              'completed': 0,
              'priority': 0,
              'due_date': null,
              'category': '',
              'version': version,
            }
          : const {},
    );
  }

  /// Scrive un archivio remoto "a mano", come se arrivasse da un altro
  /// dispositivo: è l'unico modo per costruire i casi di conflitto.
  Future<FolderSyncGateway> writeRemote(
    String name,
    List<SyncRecord> records,
  ) async {
    final target = FolderSyncGateway('${tempDir.path}/$name');
    final now = DateTime.now();
    final manifest = await ShardWriter(target).writeFresh(
      SyncManifest.empty(),
      records.first.entity,
      records,
      ShardCodec.monthKey(now),
      now,
    );
    await target.write(SyncManifest.filePath, manifest.encode());
    return target;
  }

  // ─── La prova anti-v2 ─────────────────────────────────

  test("un sync non ricarica tutto l'archivio", () async {
    seedTodos(ShardCodec.maxRecordsPerShard * 6 - 1);
    await sync.pushPending();
    expect(sync.pendingCount, 0);

    final archive = await archiveBytes();
    expect(archive, greaterThan(20000));

    gateway.reset();
    await TodoProvider(db).addTodo(title: 'una sola modifica');
    expect(await sync.pushPending(), 1);

    // La misura, non solo la soglia: è l'evidenza che il problema v2 dei file
    // che crescono è chiuso.
    // ignore: avoid_print
    print(
      'archivio ${archive ~/ 1024} KB · una modifica costa '
      '${gateway.bytesWritten} B in ${gateway.writes} scritture',
    );

    // In v2 c'era un unico JSON con tutto dentro: ogni sync ricaricava
    // l'archivio intero, e per questo diventava un problema.
    expect(
      gateway.bytesWritten,
      lessThan(64 * 1024),
      reason: "una modifica non può costare quanto tutto l'archivio",
    );
    expect(gateway.bytesWritten, lessThan(archive));
    expect(
      gateway.writes,
      lessThanOrEqualTo(3),
      reason: 'al più uno shard riscritto più il manifest',
    );
  });

  test('lo shard ruota e il precedente non viene più riscritto', () async {
    final month = ShardCodec.monthKey(DateTime.now());
    seedTodos(ShardCodec.maxRecordsPerShard + 1);
    await sync.pushPending();

    final paths = await folder.list('todo/');
    expect(paths, contains('todo/$month.jsonl.gz'));
    expect(paths, contains('todo/$month.002.jsonl.gz'));

    final closed = await folder.read('todo/$month.jsonl.gz');

    await TodoProvider(db).addTodo(title: 'dopo la rotazione');
    await sync.pushPending();

    expect(
      await folder.read('todo/$month.jsonl.gz'),
      equals(closed),
      reason: "il primo shard è chiuso: un push tocca solo l'ultimo",
    );
  });

  // ─── Export / import ──────────────────────────────────

  test('export e import rimettono gli stessi dati, con i tipi giusti',
      () async {
    await EventProvider(db).addEvent(
      title: 'Dentista',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    );
    final todoProvider = TodoProvider(db);
    await todoProvider.addTodo(
      title: 'Spesa',
      priority: 2,
      dueDate: DateTime(2026, 9, 20),
    );
    final noteProvider = NoteProvider(db);
    final folder = await noteProvider.addFolder(name: 'Lavoro');
    final note = await noteProvider.addNote(
      title: 'Idee',
      content: 'planner',
      folderId: folder.id,
    );
    await noteProvider.linkNote(
      noteId: note.id,
      entityType: 'todo',
      entityId: todoProvider.todos.single.id,
    );

    expect(await sync.exportTo(gateway), 5);

    final other = DatabaseService();
    await other.init(dbPath: ':memory:');
    addTearDown(other.close);

    final otherSync = SyncService(other)..useGateway(gateway);
    expect(await otherSync.importFrom(gateway), 5);

    expect(other.getEvents().single['title'], 'Dentista');
    expect(other.getTodos().single['title'], 'Spesa');
    expect(other.notes.all().single['content'], 'planner');
    expect(other.notes.all().single['folder_id'], folder.id);
    expect(other.notes.linksOfNote(note.id), hasLength(1));
    expect(NoteProvider(other).folders.single.name, 'Lavoro');

    // Il viaggio non deve perdere né i tipi né i campi gestiti dal database.
    expect(Event.fromRow(other.getEvents().single).allDay, isFalse);
    expect(Note.fromRow(other.notes.all().single).createdAt, isNotNull);
  });

  test('applicare due volte lo stesso archivio non cambia nulla', () async {
    await TodoProvider(db).addTodo(title: 'Spesa');
    await sync.exportTo(gateway);

    final other = DatabaseService();
    await other.init(dbPath: ':memory:');
    addTearDown(other.close);
    final otherSync = SyncService(other)..useGateway(gateway);

    expect(await otherSync.importFrom(gateway), 1);

    forgetSyncStateFor(other);
    expect(await otherSync.importFrom(gateway), 0, reason: 'idempotente');
    expect(other.getTodos(), hasLength(1));
  });

  // ─── Conflitti ────────────────────────────────────────

  test('vince il clock più alto', () async {
    db.insertTodo({
      'id': 't1',
      'title': 'locale',
      'version': 3,
      'updated_at': 3000,
    });

    final older = await writeRemote('vecchio', [
      todoRecord(
        version: 2,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        title: 'remoto-vecchio',
      ),
    ]);
    await sync.importFrom(older);
    expect(
      Todo.fromRow(db.getTodos().single).title,
      'locale',
      reason: 'un remoto più vecchio non tocca il locale',
    );

    forgetSyncState();
    final newer = await writeRemote('nuovo', [
      todoRecord(
        version: 4,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(4000),
        title: 'remoto-nuovo',
      ),
    ]);
    await sync.importFrom(newer);
    expect(Todo.fromRow(db.getTodos().single).title, 'remoto-nuovo');
  });

  test('un cancelletto remoto più nuovo elimina', () async {
    db.insertTodo({
      'id': 't1',
      'title': 'da eliminare',
      'version': 4,
      'updated_at': 4000,
    });

    final remote = await writeRemote('delete', [
      todoRecord(
        version: 5,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(5000),
        operation: SyncOperation.delete,
      ),
    ]);
    await sync.importFrom(remote);

    expect(db.getTodos(), isEmpty);
  });

  test('una modifica locale ancora in coda batte un remoto più vecchio',
      () async {
    final todos = TodoProvider(db);
    await todos.addTodo(title: 'locale in coda');
    final id = todos.todos.single.id;
    await todos.deleteTodo(id);
    // Il cancelletto è in outbox, non ancora spinto: il suo clock è il più alto.
    expect(db.outbox.pendingCount(), 2);

    final remote = await writeRemote('stale', [
      todoRecord(
        id: id,
        version: 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        title: 'resuscitato',
      ),
    ]);
    await sync.importFrom(remote);

    expect(
      db.getTodos(),
      isEmpty,
      reason: 'la cancellazione locale deve tenere',
    );
  });

  // ─── Integrità ────────────────────────────────────────

  test('uno shard manomesso viene rifiutato e non applica niente', () async {
    await TodoProvider(db).addTodo(title: 'Spesa');
    await sync.exportTo(gateway);

    final month = ShardCodec.monthKey(DateTime.now());
    final path = 'todo/$month.jsonl.gz';
    final bytes = (await folder.read(path))!;
    bytes[bytes.length - 1] ^= 0xFF; // un byte cambiato
    await folder.write(path, bytes);

    final other = DatabaseService();
    await other.init(dbPath: ':memory:');
    addTearDown(other.close);
    final otherSync = SyncService(other)..useGateway(gateway);

    await expectLater(
        otherSync.importFrom(gateway), throwsA(isA<StateError>()));
    expect(
      other.getTodos(),
      isEmpty,
      reason: 'o lo shard entra intero, o non entra affatto',
    );
  });
}

/// Cancella la memoria del sync di un altro database (usata nei test di
/// conflitto, dove si importano archivi diversi con lo stesso percorso).
void forgetSyncStateFor(DatabaseService other) {
  other.instance.execute('DELETE FROM sync_meta');
}
