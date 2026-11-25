import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/sync/encrypted_file_codec.dart';
import 'package:planner/core/sync/encrypted_sync_gateway.dart';
import 'package:planner/core/sync/folder_sync_gateway.dart';
import 'package:planner/core/sync/sync_manifest.dart';
import 'package:planner/core/sync/sync_service.dart';
import 'package:planner/features/backup/backup_attachment_files.dart';
import 'package:planner/features/backup/backup_service.dart';
import 'package:planner/features/backup/portable_encrypted_backup.dart';
import 'package:planner/features/notes/note_attachment_store.dart';
import 'package:planner/features/notes/note_attachment_sync.dart';
import 'package:planner/features/notes/note_blocks.dart';
import 'package:planner/features/notes/note_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory work;
  late Directory blobs;
  late DatabaseService database;
  late SecretKey key;
  late NoteAttachmentStore store;

  setUp(() async {
    work = await Directory.systemTemp.createTemp('planner-attachments-test-');
    blobs = Directory.fromUri(work.uri.resolve('blobs/'));
    database = DatabaseService();
    await database.init(dbPath: ':memory:');
    key = await AesGcm.with256bits().newSecretKey();
    store = NoteAttachmentStore(database, blobs, readKey: () async => key);
  });

  tearDown(() async {
    database.close();
    await work.delete(recursive: true);
  });

  test('framing multiblocco, file vuoto e identità autenticata', () async {
    final source = File.fromUri(work.uri.resolve('source'));
    final sealed = File.fromUri(work.uri.resolve('sealed'));
    final restored = File.fromUri(work.uri.resolve('restored'));
    final codec = EncryptedFileCodec(key);
    for (final length in [
      0,
      1,
      EncryptedFileCodec.blockSize,
      EncryptedFileCodec.blockSize * 2 + 9
    ]) {
      final payload = Uint8List.fromList(List.generate(length, (i) => i & 255));
      await source.writeAsBytes(payload);
      await codec.encrypt(source, sealed, identity: 'original');
      await codec.decrypt(sealed, restored, identity: 'original');
      expect(await restored.readAsBytes(), payload);
      await expectLater(
        codec.decrypt(sealed, restored, identity: 'altro'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      expect(await restored.readAsBytes(), payload);
    }
  });

  test('manomissione, troncamento e chiave errata non espongono dati',
      () async {
    final source = File.fromUri(work.uri.resolve('source'));
    final sealed = File.fromUri(work.uri.resolve('sealed'));
    final output = File.fromUri(work.uri.resolve('absent'));
    final codec = EncryptedFileCodec(key);
    await source.writeAsBytes(Uint8List(EncryptedFileCodec.blockSize + 5));
    await codec.encrypt(source, sealed, identity: 'pdf');
    final wrong = EncryptedFileCodec(await AesGcm.with256bits().newSecretKey());
    await expectLater(
        wrong.decrypt(sealed, output, identity: 'pdf'),
        throwsA(
          isA<SecretBoxAuthenticationError>(),
        ));
    final bytes = await sealed.readAsBytes();
    await sealed.writeAsBytes(bytes.sublist(0, bytes.length - 1));
    await expectLater(
        codec.decrypt(sealed, output, identity: 'pdf'), throwsFormatException);
    bytes[bytes.length - 8] ^= 1;
    await sealed.writeAsBytes(bytes);
    await expectLater(
        codec.decrypt(sealed, output, identity: 'pdf'),
        throwsA(
          isA<SecretBoxAuthenticationError>(),
        ));
    expect(await output.exists(), isFalse);
    expect(await work.list().length, 2);
  });

  test('PDF invariato, deduplica tra note, nome cifrato e confinamento',
      () async {
    final source = File.fromUri(work.uri.resolve('source.pdf'));
    const document = '%PDF-1.7\nfile sorgente\n%%EOF';
    await source.writeAsString(document);
    final first = await store.importFile(source,
        noteId: 'a',
        name: 'Bilancio riservato.pdf',
        kind: NoteAttachmentKind.pdf);
    final second = await store.importFile(source,
        noteId: 'b', name: 'Seconda copia.pdf', kind: NoteAttachmentKind.pdf);
    expect(first.blobId, second.blobId);
    expect(first.id, isNot(second.id));
    expect(await blobs.list().length, 1);
    expect(await store.read('b', first.id), isNull);
    final opened = await store.open(first, work);
    expect(await opened.readAsString(), document);
    final changed = await store.rename(first, 'Nuovo nome.pdf');
    expect(changed.blobId, first.blobId);
    expect((await store.read('a', first.id))?.name, 'Nuovo nome.pdf');
    final row = database.instance.select(
      'SELECT hex(metadata) AS metadata FROM note_attachments WHERE id = ?',
      [first.id],
    ).single;
    expect(row['metadata'], isNot(contains('4E756F766F206E6F6D65')));
  });

  test('foto ridimensionata e miniatura mantengono la trasparenza', () async {
    final source = File.fromUri(work.uri.resolve('photo.png'));
    final original = image.Image(width: 2020, height: 128, numChannels: 4);
    original.setPixelRgba(0, 0, 255, 0, 0, 120);
    await source.writeAsBytes(image.encodePng(original));
    final attachment = await store.importFile(source,
        noteId: 'a', name: 'Foto.png', kind: NoteAttachmentKind.photo);
    final file = await store.open(attachment, work);
    final full = image.decodePng(await file.readAsBytes())!;
    expect(full.width, 2000);
    expect(full.hasAlpha, isTrue);
    final mini = await store.open(attachment, work, thumbnail: true);
    expect(image.decodePng(await mini.readAsBytes())?.width, 320);
  });

  test('file non PDF scartato senza creare un riferimento', () async {
    final file =
        await File.fromUri(work.uri.resolve('fake.pdf')).writeAsString('test');
    await expectLater(
        store.importFile(file,
            noteId: 'a', name: 'fake.pdf', kind: NoteAttachmentKind.pdf),
        throwsFormatException);
    expect(
        database.instance.select('SELECT id FROM note_attachments'), isEmpty);
  });

  test('empty files and one byte over the PDF or photo limit are rejected',
      () async {
    for (final (kind, limit) in [
      (NoteAttachmentKind.pdf, NoteAttachmentStore.maxPdfBytes),
      (NoteAttachmentKind.photo, NoteAttachmentStore.maxPhotoBytes),
    ]) {
      final file = File.fromUri(work.uri.resolve(kind.name));
      for (final length in [0, limit + 1]) {
        final output = await file.open(mode: FileMode.write);
        await output.truncate(length);
        await output.close();
        await expectLater(
          store.importFile(file, noteId: 'draft', name: kind.name, kind: kind),
          throwsA(isA<FormatException>().having(
              (error) => error.message,
              'messaggio',
              contains(length == 0 ? 'vuot' : 'supera il limite'))),
        );
      }
    }
    expect(
        database.instance.select('SELECT id FROM note_attachments'), isEmpty);
  });

  test('riferimenti allegato convivono con checklist e testo', () {
    const id = 'aaafbaee-cc17-48fb-ab5c-2a33d8b971bc';
    final blocks = parseNoteBlocks('testo\n${attachmentLine(id)}\n- [x] fine');
    expect(blocks.map((block) => block.kind), [
      NoteBlockKind.paragraph,
      NoteBlockKind.attachment,
      NoteBlockKind.checkbox
    ]);
    expect(blocks[1].text, id);
  });

  test('la chiave Drive si salva solo dopo la verifica e si può riprovare',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final device = NoteAttachmentStore(database, blobs);
    final gateway = FolderSyncGateway(work.uri.resolve('remote/').toFilePath());
    final archive = EncryptedSyncGateway(gateway, key);
    await expectLater(archive.verifyExistingArchiveKey(), throwsStateError);
    expect(await gateway.list(''), isEmpty);
    await archive.requireCompatibleArchive(SyncManifest.filePath);

    Future<String> codeFor(SecretKey value) async =>
        'PLANNER1-${base64Url.encode(await value.extractBytes()).replaceAll('=', '')}';
    Future<void> verify(SecretKey value) =>
        EncryptedSyncGateway(gateway, value).verifyExistingArchiveKey();

    final wrong = await codeFor(await AesGcm.with256bits().newSecretKey());
    await expectLater(device.useRecoveryCode(wrong, verify: verify),
        throwsA(isA<ArchiveRecoveryRequired>()));
    await expectLater(device.recoveryCode(), throwsStateError);

    final correct = await codeFor(key);
    await device.useRecoveryCode(correct, verify: verify);
    final restarted = NoteAttachmentStore(database, blobs);
    expect(await restarted.recoveryCode(), correct);
    expect(await restarted.recoveryCopyConfirmed(), isFalse);
    await expectLater(
        restarted.confirmRecoveryCopy(wrong), throwsFormatException);
    await restarted.confirmRecoveryCopy(correct);
    expect(await device.recoveryCopyConfirmed(), isTrue);
  });

  test('due archivi sincronizzano riferimenti e scaricano il blob su richiesta',
      () async {
    final gateway = FolderSyncGateway(work.uri.resolve('remote/').toFilePath());
    final source = EncryptedSyncGateway(gateway, key);
    await source.requireCompatibleArchive(SyncManifest.filePath);
    final wrong = EncryptedSyncGateway(
        gateway, await AesGcm.with256bits().newSecretKey());
    await expectLater(wrong.requireCompatibleArchive(SyncManifest.filePath),
        throwsStateError);
    final writer =
        SyncService(database, files: NoteAttachmentSync(database, store))
          ..useGateway(source);
    final localNotes = NoteProvider(database);
    addTearDown(localNotes.dispose);
    final note = await localNotes.addNote(title: 'Titolo riservato');
    final document = await File.fromUri(work.uri.resolve('original.pdf'))
        .writeAsString('%PDF-1.7\ncontenuto riservato\n%%EOF');
    final attachment = await store.importFile(document,
        noteId: note.id,
        name: 'Nome riservato.pdf',
        kind: NoteAttachmentKind.pdf);
    await localNotes
        .updateNote(note.copyWith(content: attachmentLine(attachment.id)));
    expect(await writer.pushPending(), 2);
    final rawNames = await gateway.list('');
    expect(
        rawNames
            .any((name) => name.contains('manifest') || name.contains('note/')),
        isFalse);
    for (final name in rawNames) {
      expect(String.fromCharCodes((await gateway.read(name))!),
          isNot(contains('Titolo riservato')));
    }

    final other = DatabaseService();
    await other.init(dbPath: ':memory:');
    addTearDown(other.close);
    final otherBlobs = Directory.fromUri(work.uri.resolve('receiver/'));
    final destination = EncryptedSyncGateway(gateway, key);
    final receivingStore = NoteAttachmentStore(other, otherBlobs,
        readKey: () async => key, remote: () => destination);
    final reader =
        SyncService(other, files: NoteAttachmentSync(other, receivingStore))
          ..useGateway(destination);
    expect(await reader.pullChanges(), greaterThan(0));
    expect(await otherBlobs.exists(), isFalse);
    final pulled = (await receivingStore.read(note.id, attachment.id))!;
    final restored = await receivingStore.open(pulled, work);
    expect(await restored.readAsBytes(), await document.readAsBytes());

    await store.rename(attachment, 'Rinominato.pdf');
    await localNotes.updateNote(localNotes.byId(note.id)!);
    expect(await writer.pushPending(), 1);
    expect(await reader.pullChanges(), greaterThan(0));
    expect((await receivingStore.read(note.id, attachment.id))?.name,
        'Rinominato.pdf');
    expect((await gateway.list('encrypted-v1/blob/')).length, 1);
  });

  test(
      'backup portabile si ripristina su un nuovo database con la stessa chiave',
      () async {
    final originDir =
        await Directory.fromUri(work.uri.resolve('origin/')).create();
    final originDb = DatabaseService();
    await originDb.init(
        dbPath: File.fromUri(originDir.uri.resolve('planner.db')).path);
    addTearDown(originDb.close);
    final sourceBlobs =
        Directory.fromUri(originDir.uri.resolve('note-attachments/'));
    final sourceStore =
        NoteAttachmentStore(originDb, sourceBlobs, readKey: () async => key);
    final notes = NoteProvider(originDb);
    addTearDown(notes.dispose);
    final note = await notes.addNote(title: 'Recupera');
    final source = await File.fromUri(work.uri.resolve('source.pdf'))
        .writeAsString('%PDF-1.7\n%%EOF');
    final attachment = await sourceStore.importFile(source,
        noteId: note.id, name: 'Originale.pdf', kind: NoteAttachmentKind.pdf);
    await notes
        .updateNote(note.copyWith(content: attachmentLine(attachment.id)));
    final backups = Directory.fromUri(work.uri.resolve('snapshots/'));
    final snapshot =
        await BackupService(originDb, cartella: backups).snapshot();
    final snapshotFile = File.fromUri(backups.uri.resolve(snapshot.name));
    final snapshotPool =
        Directory.fromUri(backups.uri.resolve('note-attachments/'));
    await BackupAttachmentFiles.verifyInPool(
        snapshotPool, snapshotFile, () async => key);
    await expectLater(
      BackupAttachmentFiles.verifyInPool(
        snapshotPool,
        snapshotFile,
        () async => SecretKey(List.filled(32, 0)),
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    const portable = PortableEncryptedBackup();
    final staging =
        await Directory.fromUri(work.uri.resolve('export/')).create();
    final sealed = await portable.write(
      database: snapshotFile,
      blobPool: snapshotPool,
      staging: staging,
      key: key,
    );
    final newDir = await Directory.fromUri(work.uri.resolve('new/')).create();
    final restoredDb = DatabaseService();
    await restoredDb.init(
        dbPath: File.fromUri(newDir.uri.resolve('planner.db')).path);
    addTearDown(restoredDb.close);
    final newBackups = Directory.fromUri(work.uri.resolve('new-snapshots/'));
    final newPool =
        Directory.fromUri(newBackups.uri.resolve('note-attachments/'));
    final stage = await Directory.fromUri(work.uri.resolve('import/')).create();
    restoredDb.insertEvent({
      'id': 'local',
      'title': 'Evento sul telefono',
      'start_time': 1000,
      'end_time': 2000,
    });
    final wrong = await AesGcm.with256bits().newSecretKey();
    await expectLater(portable.verifyKey(sealed, wrong),
        throwsA(isA<SecretBoxAuthenticationError>()));
    await portable.verifyKey(sealed, key);
    await expectLater(
        portable.read(
            sealed: sealed, staging: stage, blobPool: newPool, key: wrong),
        throwsA(isA<SecretBoxAuthenticationError>()));
    expect(await newPool.exists(), isFalse);
    final truncated = File.fromUri(work.uri.resolve('truncated.planner'));
    final damaged = File.fromUri(work.uri.resolve('damaged.planner'));
    final bytes = await sealed.readAsBytes();
    await truncated.writeAsBytes(bytes.sublist(0, bytes.length - 1));
    bytes[bytes.length - 1] ^= 1;
    await damaged.writeAsBytes(bytes);
    for (final corrupt in [truncated, damaged]) {
      await expectLater(
        portable.read(
            sealed: corrupt, staging: stage, blobPool: newPool, key: key),
        throwsA(
            anyOf(isA<FormatException>(), isA<SecretBoxAuthenticationError>())),
      );
      expect(await newPool.exists(), isFalse);
      expect(await stage.list().toList(), isEmpty);
      expect(restoredDb.getEvents().single['id'], 'local');
    }
    final recovered = await portable.read(
        sealed: sealed, staging: stage, blobPool: newPool, key: key);
    await BackupService(restoredDb, cartella: newBackups)
        .ripristinaEsterna(recovered.path);
    final restoredStore = NoteAttachmentStore(
      restoredDb,
      Directory.fromUri(newDir.uri.resolve('note-attachments/')),
      readKey: () async => key,
    );
    final item = (await restoredStore.read(note.id, attachment.id))!;
    expect(item.name, 'Originale.pdf');
    expect(await (await restoredStore.open(item, work)).readAsBytes(),
        await source.readAsBytes());
  });
}
