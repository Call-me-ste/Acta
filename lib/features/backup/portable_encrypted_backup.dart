import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../../core/sync/encrypted_file_codec.dart';
import 'backup_attachment_files.dart';

class PortableBackupTooLarge extends FormatException {
  const PortableBackupTooLarge()
      : super('La copia supera il limite supportato da Acta.');
}

/// A standalone SQLite snapshot and its immutable attachments, authenticated
/// as one portable archive using the user's recovery key.
class PortableEncryptedBackup {
  const PortableEncryptedBackup();

  static const extension = '.planner';
  static const _identity = 'planner/portable-backup/v1';
  static const _database = 'planner.db';
  static const _maximumSize = 32 * 1024 * 1024 * 1024;
  static const maximumFileSize = _maximumSize + 4 * 1024 * 1024;

  Future<void> verifyKey(File sealed, SecretKey key) async {
    final path = sealed.path;
    if (await sealed.length() > maximumFileSize) {
      throw const PortableBackupTooLarge();
    }
    final bytes = await key.extractBytes();
    await Isolate.run(() => EncryptedFileCodec(SecretKey(bytes))
        .verify(File(path), identity: _identity));
  }

  Future<File> write({
    required File database,
    required Directory blobPool,
    required Directory staging,
    required SecretKey key,
  }) async {
    final data = (
      database: database.path,
      pool: blobPool.path,
      stage: staging.path,
      key: await key.extractBytes()
    );
    return Isolate.run(() => _write(data));
  }

  Future<File> read({
    required File sealed,
    required Directory staging,
    required Directory blobPool,
    required SecretKey key,
  }) async {
    final data = (
      sealed: sealed.path,
      pool: blobPool.path,
      stage: staging.path,
      key: await key.extractBytes()
    );
    return Isolate.run(() => _read(data));
  }

  static Future<File> _write(
    ({String database, String pool, String stage, List<int> key}) data,
  ) async {
    final database = File(data.database);
    final zip = File(p.join(data.stage, 'content.zip'));
    final codec = EncryptedFileCodec(SecretKey(data.key));
    final attachments = <File>[];
    var size = await database.length();
    for (final id in BackupAttachmentFiles.references(database)) {
      for (final extension in ['.blob', '.thumb']) {
        final file = File(p.join(data.pool, id + extension));
        if (extension == '.thumb' && !await file.exists()) continue;
        size += await file.length();
        if (size > _maximumSize) throw const PortableBackupTooLarge();
        attachments.add(file);
      }
    }
    if (size > _maximumSize) throw const PortableBackupTooLarge();
    try {
      final files = ZipFileEncoder()
        ..create(zip.path, level: ZipFileEncoder.store);
      try {
        await files.addFile(database, _database);
        for (final file in attachments) {
          final name = p.basename(file.path);
          await codec.verify(file, identity: name);
          await files.addFile(file, name);
        }
      } finally {
        await files.close();
      }
      if (await zip.length() > _maximumSize) {
        throw const PortableBackupTooLarge();
      }
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final archive = File(p.join(data.stage, 'Planner-$date$extension'));
      await codec.encrypt(zip, archive, identity: _identity);
      return archive;
    } finally {
      if (await zip.exists()) await zip.delete();
    }
  }

  static Future<File> _read(
    ({String sealed, String pool, String stage, List<int> key}) data,
  ) async {
    final sealed = File(data.sealed);
    if (await sealed.length() > maximumFileSize) {
      throw const PortableBackupTooLarge();
    }
    final codec = EncryptedFileCodec(SecretKey(data.key));
    final zip = File(p.join(data.stage, 'import.zip'));
    await codec.decrypt(sealed, zip, identity: _identity);
    final names = <String>{};
    final stream = InputFileStream(zip.path);
    var total = 0;
    try {
      final archive = ZipDecoder().decodeStream(stream, throwOnError: true);
      final allowed = RegExp(r'^[a-f0-9]{64}\.(blob|thumb)$');
      for (final entry in archive) {
        if (!entry.isFile ||
            entry.isSymbolicLink ||
            (entry.name != _database && !allowed.hasMatch(entry.name)) ||
            !names.add(entry.name)) {
          throw const FormatException('Contenuto della copia non valido');
        }
        total += entry.size;
        if (entry.size < 0 || total > _maximumSize) {
          throw const FormatException('Dimensione della copia non valida');
        }
        final output = OutputFileStream(p.join(data.stage, entry.name));
        try {
          entry.writeContent(output);
        } finally {
          await output.close();
        }
      }
    } finally {
      await stream.close();
      await zip.delete();
    }
    if (!names.remove(_database)) {
      throw const FormatException('Database assente');
    }
    final database = File(p.join(data.stage, _database));
    final blobs = BackupAttachmentFiles.references(database);
    if (blobs.any((id) => !names.contains('$id.blob')) ||
        names.any((name) => !blobs.contains(name.substring(0, 64)))) {
      throw const FormatException('Allegati incompleti nella copia');
    }
    for (final name in names) {
      await codec.verify(File(p.join(data.stage, name)), identity: name);
    }
    await BackupAttachmentFiles(
      Directory(data.pool),
      Directory(data.stage),
    ).restore(database);
    return database;
  }
}
