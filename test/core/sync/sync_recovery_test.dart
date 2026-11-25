import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/sync/encrypted_sync_gateway.dart';
import 'package:planner/core/sync/folder_sync_gateway.dart';
import 'package:planner/core/sync/shard_codec.dart';
import 'package:planner/core/sync/sync_manifest.dart';
import 'package:planner/core/sync/sync_record.dart';
import 'package:planner/core/sync/sync_service.dart';
import 'package:planner/features/backup/backup_service.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_attachment_store.dart';
import 'package:planner/features/notes/note_attachment_sync.dart';
import 'package:planner/features/notes/note_blocks.dart';
import 'package:planner/features/notes/note_provider.dart';

void main() {
  late Directory temp;
  late DatabaseService first;
  late DatabaseService second;
  late EncryptedSyncGateway vault;
  late SecretKey key;
  final day = DateTime(2026, 5, 1);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('planner-recovery-test-');
    first = DatabaseService();
    second = DatabaseService();
    await first.init(dbPath: ':memory:');
    await second.init(dbPath: temp.uri.resolve('replica.db').toFilePath());
    key = SecretKey(List.filled(32, 7));
    vault = EncryptedSyncGateway(
      FolderSyncGateway(temp.uri.resolve('cloud/').toFilePath()),
      key,
    );
    await vault.requireCompatibleArchive(SyncManifest.filePath);
  });

  tearDown(() async {
    first.close();
    second.close();
    await temp.delete(recursive: true);
  });

  SyncService connect(DatabaseService db) =>
      SyncService(db)..useGateway(vault, accountKey: 'account@example.com');

  test('first sync publishes local records absent from the queue once',
      () async {
    first.insertEvent(
        Event(id: 'old', title: 'Evento locale', start: day, end: day)
            .toParams());
    final writer = connect(first);
    await writer.fullSync();
    expect(writer.pendingCount, 0);
    final reader = connect(second);
    expect(await reader.fullSync(), 1);
    expect(second.getEvents().single['id'], 'old');
    expect(await connect(second).fullSync(), 0);
    expect(await vault.listChanges(), hasLength(1));
  });

  test('first sync after upgrade does not republish previously read records',
      () async {
    first.insertEvent(
        Event(id: 'old', title: 'Evento locale', start: day, end: day)
            .toParams());
    await connect(first).fullSync();
    await (SyncService(second)..useGateway(vault)).fullSync();
    expect(second.getEvents(), hasLength(1));
    expect(await connect(second).fullSync(), 0);
    expect(await vault.listChanges(), hasLength(1));
  });

  test('restoring an old backup replays Drive additions and deletions',
      () async {
    final events = EventProvider(first);
    final writer = connect(first);
    final reader = connect(second);
    final obsolete =
        await events.addEvent(title: 'Prima', start: day, end: day);
    await writer.fullSync();
    await reader.fullSync();
    final backups = BackupService(second,
        cartella: Directory.fromUri(temp.uri.resolve('backups/')));
    final old = await backups.snapshot();

    await events.deleteEvent(obsolete.id);
    final present = await events.addEvent(title: 'Dopo', start: day, end: day);
    await writer.fullSync();
    await reader.fullSync();
    await backups.ripristina(old);
    expect(second.getEvents().single['id'], obsolete.id);
    expect(reader.lastSyncTime, isNull);

    await reader.fullSync();
    expect(second.getEvents().single['id'], present.id);
    expect(await reader.fullSync(), 0);
  });

  test('manual recovery keeps pending edits and restores missing items',
      () async {
    final events = EventProvider(first);
    final old =
        await events.addEvent(title: 'Da aggiornare', start: day, end: day);
    final missing =
        await events.addEvent(title: 'Da recuperare', start: day, end: day);
    final writer = connect(first);
    final reader = connect(second);
    await writer.fullSync();
    await reader.fullSync();
    await EventProvider(second)
        .updateEvent(old.copyWith(title: 'Aggiornato offline'));
    second.deleteEvent(missing.id);

    await reader.recoverRemote();
    await writer.fullSync();
    expect(second.getEvents().map((row) => row['title']),
        unorderedEquals(['Aggiornato offline', 'Da recuperare']));
    expect(first.getEvents().map((row) => row['title']),
        unorderedEquals(['Aggiornato offline', 'Da recuperare']));
    expect(reader.pendingCount, 0);
  });

  test('switching accounts cannot send a previously connected queue', () async {
    final writer = connect(first);
    await writer.fullSync();
    await EventProvider(first)
        .addEvent(title: 'Solo sul primo account', start: day, end: day);
    writer.useGateway(null);
    final other = EncryptedSyncGateway(
      FolderSyncGateway(temp.uri.resolve('other/').toFilePath()),
      key,
    );
    expect(() => writer.useGateway(other, accountKey: 'other@example.com'),
        throwsStateError);
    expect(writer.pendingCount, 1);
    expect(await other.listChanges(), isEmpty);
  });

  test('same version and timestamp converge regardless of the local edit',
      () async {
    Event edit(String title) => Event(
        id: 'conflict',
        title: title,
        start: day,
        end: day,
        version: 2,
        updatedAt: day);
    first.insertEvent(edit('A').toParams());
    second.insertEvent(edit('Z').toParams());
    for (final title in ['A', 'Z']) {
      final bytes = ShardCodec.encode([
        SyncRecord(
            entity: 'event',
            id: 'conflict',
            operation: SyncOperation.upsert,
            version: 2,
            updatedAt: day,
            data: edit(title).toParams()),
      ]);
      await vault.writeChange(await vault.changePath(bytes), bytes);
    }
    await connect(first).fullSync();
    await connect(second).fullSync();
    expect(first.getEvents().single['title'], 'Z');
    expect(second.getEvents().single['title'], 'Z');
    expect(await vault.listChanges(), hasLength(2));
  });

  test('losing a previously linked archive cannot acknowledge pending data',
      () async {
    final writer = connect(first);
    final events = EventProvider(first);
    await events.addEvent(title: 'Già inviata', start: day, end: day);
    final deleted =
        await events.addEvent(title: 'Da cancellare', start: day, end: day);
    final other = connect(second);
    await writer.fullSync();
    await other.fullSync();
    await events.deleteEvent(deleted.id);
    await writer.fullSync();
    final lastSync = writer.lastSyncTime;
    await events.addEvent(title: 'In attesa', start: day, end: day);
    final remote = FolderSyncGateway(temp.uri.resolve('cloud/').toFilePath());
    await remote.delete('encrypted-v1/archive');

    await expectLater(writer.fullSync(), throwsA(isA<DriveArchiveMissing>()));
    await expectLater(
      EncryptedSyncGateway(remote, key).requireCompatibleArchive(
        SyncManifest.filePath,
        requireExisting: writer.hasArchiveBinding,
      ),
      throwsA(isA<DriveArchiveMissing>()),
    );
    expect(writer.pendingCount, 1);
    expect(writer.lastSyncTime, lastSync);
    expect(first.getEvents(), hasLength(2));

    for (final path in await remote.list('')) {
      await remote.delete(path);
    }
    final fresh = EncryptedSyncGateway(remote, key);
    await fresh.requireCompatibleArchive(SyncManifest.filePath,
        beforeInitialize: () =>
            writer.enqueueForNewArchive('account@example.com'));
    writer.useGateway(fresh, accountKey: 'account@example.com');
    expect(writer.lastSyncTime, isNull);
    await writer.fullSync();
    expect(await other.fullSync(), 2);
    expect(second.getEvents().map((row) => row['title']),
        unorderedEquals(['Già inviata', 'In attesa']));
  });

  test('a removed attachment in an old edit does not block the latest note',
      () async {
    final notes = NoteProvider(first);
    final note = await notes.addNote(title: 'Nota');
    final attachment = attachmentLine('aaafbaee-cc17-48fb-ab5c-2a33d8b971bc');
    await notes.updateNote(note.copyWith(content: attachment));
    await notes
        .updateNote(notes.byId(note.id)!.copyWith(content: 'Testo finale'));
    final storage = NoteAttachmentStore(first, temp, readKey: () async => key);
    final writer = SyncService(first, files: NoteAttachmentSync(first, storage))
      ..useGateway(vault, accountKey: 'account@example.com');
    final reader = connect(second);
    await writer.fullSync();
    await reader.fullSync();
    expect(writer.pendingCount, 0);
    expect(second.notes.all().single['content'], 'Testo finale');
  });

  test('an existing sync receipt identifies the account after upgrading', () {
    first.meta.set('sync_receipt:account@example.com', '2026-05-01T09:00:00,1');
    final writer = SyncService(first);
    expect(() => writer.useGateway(vault, accountKey: 'other@example.com'),
        throwsA(isA<ArchiveAccountMismatch>()));
    writer.useGateway(vault, accountKey: 'account@example.com');
    expect(writer.isConfigured, isTrue);
  });
}
