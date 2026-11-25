import 'dart:convert';

import '../../core/database/database_service.dart';
import '../../core/sync/encrypted_sync_gateway.dart';
import '../../core/sync/sync_gateway.dart';
import '../../core/sync/sync_record.dart';
import '../../core/sync/sync_record_files.dart';
import 'note_attachment_store.dart';
import 'note_blocks.dart';

class NoteAttachmentSync implements SyncRecordFiles {
  NoteAttachmentSync(this._database, this._store);

  final DatabaseService _database;
  final NoteAttachmentStore _store;
  final _uploaded = Expando<Set<String>>();
  static const _field = 'attachments_v1';

  @override
  Future<SyncRecord> prepare(SyncGateway gateway, SyncRecord record) async {
    if (record.entity != 'note' || record.operation != SyncOperation.upsert) {
      return record;
    }
    final body = record.data['content'] as String? ?? '';
    final ids = attachmentIds(body);
    if (ids.isEmpty) return record;
    if (gateway is! EncryptedSyncGateway) {
      throw StateError(
          'Gli allegati richiedono un archivio sincronizzato cifrato.');
    }
    final records = <Map<String, String>>[];
    final cached = _uploaded[gateway] ??= {};
    final rows = _database.instance.select(
      'SELECT id, blob_id, metadata FROM note_attachments WHERE note_id = ?',
      [record.id],
    );
    for (final row in rows) {
      final id = row['id'] as String;
      if (!ids.remove(id)) continue;
      final blob = row['blob_id'] as String;
      await _publish(gateway, cached, '$blob.blob', required: true);
      await _publish(gateway, cached, '$blob.thumb', required: false);
      records.add({
        'id': id,
        'blob': blob,
        'metadata': base64Url.encode(row['metadata'] as List<int>),
      });
    }
    if (ids.isNotEmpty) {
      throw StateError('Uno o più allegati non sono disponibili.');
    }
    return SyncRecord(
      entity: record.entity,
      id: record.id,
      operation: record.operation,
      version: record.version,
      updatedAt: record.updatedAt,
      data: {...record.data, _field: records},
    );
  }

  Future<void> _publish(
      EncryptedSyncGateway gateway, Set<String> cached, String name,
      {required bool required}) async {
    if (cached.contains(name)) return;
    final blob = _store.blobFile(name);
    final path = remoteAttachmentPath(name);
    if (await gateway.hasAttachment(path)) {
      cached.add(name);
      return;
    }
    if (await blob.exists()) {
      await gateway.uploadAttachment(path, blob);
      cached.add(name);
    } else if (required) {
      throw StateError(
          'File dell’allegato non disponibile per il caricamento.');
    }
  }

  @override
  void apply(SyncRecord record) {
    if (record.entity != 'note' || !record.data.containsKey(_field)) return;
    final ids = attachmentIds(record.data['content'] as String);
    final entries = record.data[_field] as List;
    if (entries.length != ids.length) {
      throw const FormatException('Riferimenti degli allegati incompleti');
    }
    for (final entry in entries.cast<Map>()) {
      final id = entry['id'] as String;
      final blob = entry['blob'] as String;
      _store.blobFile('$blob.blob');
      final metadata = base64Url.decode(entry['metadata'] as String);
      if (!ids.remove(id) || metadata.length < 28 || metadata.length > 2048) {
        throw const FormatException('Metadati allegato non validi');
      }
      _database.instance.execute(
        'INSERT INTO note_attachments (id, note_id, blob_id, metadata) VALUES (?, ?, ?, ?) '
        'ON CONFLICT(id) DO UPDATE SET blob_id = excluded.blob_id, metadata = excluded.metadata '
        'WHERE note_attachments.note_id = excluded.note_id',
        [id, record.id, blob, metadata],
      );
    }
  }
}
