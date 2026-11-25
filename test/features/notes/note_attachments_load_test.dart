import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/sync/encrypted_sync_gateway.dart';
import 'package:planner/core/sync/folder_sync_gateway.dart';
import 'package:planner/core/sync/sync_service.dart';
import 'package:planner/features/notes/domain/note.dart';
import 'package:planner/features/notes/note_attachment_store.dart';
import 'package:planner/features/notes/note_attachment_sync.dart';
import 'package:planner/features/notes/note_blocks.dart';

void main() {
  const enabled = bool.fromEnvironment('PLANNER_ATTACHMENT_LOAD');

  test('PDF al limite di 100 MiB con scrittura e lettura a blocchi', () async {
    final dir = await Directory.systemTemp.createTemp('planner-large-pdf-');
    addTearDown(() => dir.delete(recursive: true));
    final db = DatabaseService();
    await db.init(dbPath: ':memory:');
    addTearDown(db.close);
    final key = await AesGcm.with256bits().newSecretKey();
    final store = NoteAttachmentStore(
        db, Directory.fromUri(dir.uri.resolve('blobs/')),
        readKey: () async => key);
    const length = NoteAttachmentStore.maxPdfBytes;
    final pdf = File.fromUri(dir.uri.resolve('source.pdf'));
    final fd = await pdf.open(mode: FileMode.write);
    await fd.writeString('%PDF-1.7\n');
    await fd.truncate(length);
    await fd.setPosition(length - 5);
    await fd.writeString('%%EOF');
    await fd.close();
    final timer = Stopwatch()..start();
    final attachment = await store.importFile(pdf,
        noteId: 'large', name: 'Large.pdf', kind: NoteAttachmentKind.pdf);
    final imported = timer.elapsedMilliseconds;
    final restored = await store.open(attachment, dir);
    expect(await restored.length(), length);
    final read = await restored.open();
    try {
      await read.setPosition(length - 5);
      expect(String.fromCharCodes(await read.read(5)), '%%EOF');
    } finally {
      await read.close();
    }
    // ignore: avoid_print
    print(
        'PDF 100 MiB: import ${imported}ms, lettura ${timer.elapsedMilliseconds - imported}ms.');
  },
      skip: enabled
          ? false
          : 'Carico esplicito, abilitare PLANNER_ATTACHMENT_LOAD',
      timeout: const Timeout(Duration(minutes: 5)));

  test('10.000 note, 2.000 riferimenti foto e 200 riferimenti PDF', () async {
    final time = Stopwatch()..start();
    final work = await Directory.systemTemp.createTemp('planner-load-');
    addTearDown(() => work.delete(recursive: true));
    final db = DatabaseService();
    await db.init(dbPath: ':memory:');
    addTearDown(db.close);
    final destination = DatabaseService();
    await destination.init(dbPath: ':memory:');
    addTearDown(destination.close);
    final key = await AesGcm.with256bits().newSecretKey();
    final photos = await File.fromUri(work.uri.resolve('photo.png'))
        .writeAsBytes(image.encodePng(image.Image(width: 64, height: 64)));
    final pdf = await File.fromUri(work.uri.resolve('document.pdf'))
        .writeAsString('%PDF-1.7\n%%EOF');
    final store = NoteAttachmentStore(
        db, Directory.fromUri(work.uri.resolve('blobs/')),
        readKey: () async => key);
    final remote = FolderSyncGateway(work.uri.resolve('remote/').toFilePath());
    final encrypted = EncryptedSyncGateway(remote, key);
    final writer = SyncService(db, files: NoteAttachmentSync(db, store));
    final local =
        await Directory.fromUri(work.uri.resolve('download/')).create();
    final localStore =
        NoteAttachmentStore(destination, local, readKey: () async => key);
    final reader = SyncService(destination,
        files: NoteAttachmentSync(destination, localStore));
    final noteDrafts = <Note>[];
    for (var i = 0; i < 10000; i++) {
      final id = 'note-$i';
      String content = 'Testo sintetico $i';
      if (i < 2200) {
        final photo = i < 2000;
        final attachment = await store.importFile(photo ? photos : pdf,
            noteId: id,
            name: photo ? 'Foto.png' : 'PDF.pdf',
            kind: photo ? NoteAttachmentKind.photo : NoteAttachmentKind.pdf);
        content = '$content\n${attachmentLine(attachment.id)}';
      }
      noteDrafts.add(Note(id: id, title: 'Nota $i', content: content));
    }
    db.runInTransaction(() {
      for (final note in noteDrafts) {
        db.notes.insert(note.toParams());
      }
    });
    final imported = time.elapsedMilliseconds;
    expect(await writer.exportTo(encrypted), 10000);
    final exported = time.elapsedMilliseconds;
    expect(await reader.importFrom(encrypted), 10000);
    expect(await local.list().length, 0, reason: 'download su richiesta');
    expect(
        destination.instance
            .select('SELECT count(*) n FROM note_attachments')
            .single['n'],
        2200);
    expect((await remote.list('encrypted-v1/blob/')).length, 3);
    // ignore: avoid_print
    print('Import fixture ${imported}ms, export ${exported - imported}ms, '
        'pull ${time.elapsedMilliseconds - exported}ms; file deduplicati.');
  },
      skip: enabled
          ? false
          : 'Carico esplicito, abilitare PLANNER_ATTACHMENT_LOAD',
      timeout: const Timeout(Duration(minutes: 5)));
}
