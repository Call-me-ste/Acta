import 'dart:io';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../core/sync/encrypted_file_codec.dart';
import '../notes/note_blocks.dart';

/// Shared pool for local snapshots. A blob is copied once across all snapshots.
class BackupAttachmentFiles {
  const BackupAttachmentFiles(this.live, this.pool);

  final Directory live;
  final Directory pool;

  static Set<String> references(File snapshot) {
    final db = sqlite3.open(snapshot.path, mode: OpenMode.readOnly);
    try {
      if (db
          .select("SELECT 1 FROM sqlite_master WHERE name = 'note_attachments'")
          .isEmpty) {
        return {};
      }
      final references = <String>{};
      final notes = {
        for (final row in db.select(
            "SELECT id, content FROM notes WHERE content LIKE '%attachment:%'"))
          row['id'] as String: attachmentIds(row['content'] as String),
      };
      for (final row in db.select(
        'SELECT a.blob_id, a.id, n.id AS note_id FROM note_attachments a '
        "JOIN notes n ON n.id = a.note_id WHERE n.content LIKE '%attachment:%'",
      )) {
        if (notes[row['note_id'] as String]?.remove(row['id'] as String) !=
            true) {
          continue;
        }
        final blob = row['blob_id'] as String;
        if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(blob)) {
          throw const FormatException('Riferimento file allegato non valido');
        }
        references.add(blob);
      }
      if (notes.values.any((ids) => ids.isNotEmpty)) {
        throw const FileSystemException(
            'Riferimenti degli allegati incompleti');
      }
      return references;
    } finally {
      db.dispose();
    }
  }

  Future<void> save(File snapshot) => _copy(snapshot, from: live, to: pool);
  Future<void> restore(File snapshot) => _copy(snapshot, from: pool, to: live);

  static Future<void> verifyInPool(
    Directory pool,
    File snapshot,
    Future<SecretKey> Function() readKey,
  ) async {
    final snapshotPath = snapshot.path;
    final ids = await Isolate.run(() => references(File(snapshotPath)));
    if (ids.isEmpty) return;
    final poolPath = pool.path;
    final key = await (await readKey()).extractBytes();
    await Isolate.run(() async {
      final codec = EncryptedFileCodec(SecretKey(key));
      for (final id in ids) {
        for (final suffix in ['.blob', '.thumb']) {
          final name = '$id$suffix';
          final file = File(p.join(poolPath, name));
          if (suffix == '.thumb' && !await file.exists()) continue;
          await codec.verify(file, identity: name);
        }
      }
    });
  }

  Future<void> _copy(
    File snapshot, {
    required Directory from,
    required Directory to,
  }) async {
    for (final id in references(snapshot)) {
      await _transfer('$id.blob', from, to, required: true);
      await _transfer('$id.thumb', from, to, required: false);
    }
  }

  Future<void> _transfer(String name, Directory from, Directory to,
      {required bool required}) async {
    final destination = File(p.join(to.path, name));
    if (await destination.exists()) return;
    final source = File(p.join(from.path, name));
    if (!await source.exists()) {
      if (required) {
        throw const FileSystemException('Allegato assente nella copia');
      }
      return;
    }
    await to.create(recursive: true);
    final stage = await to.createTemp('.snapshot-');
    try {
      final copy = await source.copy(p.join(stage.path, name));
      await copy.rename(destination.path);
    } finally {
      await stage.delete(recursive: true);
    }
  }
}
