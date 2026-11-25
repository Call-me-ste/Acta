import 'dart:convert';

import 'encrypted_sync_gateway.dart';
import 'hash.dart';
import 'shard_codec.dart';
import 'sync_gateway.dart';
import 'sync_manifest.dart';
import 'sync_record.dart';

/// Scrive i record sugli shard, applicando la rotazione.
///
/// Sta separato dal servizio perché è il pezzo che **entrambe** le strade usano
/// — il push (che aggiunge allo shard corrente) e l'export (che parte da zero) —
/// e perché `SyncService` deve restare sotto le 300 righe.
class ShardWriter {
  ShardWriter(this._gateway);

  final SyncGateway _gateway;

  /// Aggiunge i record allo shard corrente dell'entità: rilegge quello che c'è,
  /// lo estende, e ruota quando è pieno.
  ///
  /// Un push tocca **al più uno shard per entità**: è la proprietà che rende il
  /// costo di un sync proporzionale alla modifica e non a quanto possiedi.
  Future<SyncManifest> appendToCurrent(
    SyncManifest manifest,
    String entity,
    List<SyncRecord> records,
    String month,
    DateTime now,
  ) async {
    var part = 1;
    var buffer = <SyncRecord>[];

    final current = manifest.latestFor(entity);
    if (current != null && current.month == month) {
      final bytes = await _gateway.read(current.path);
      if (bytes == null) {
        // Il manifest dichiara uno shard che non c'è: meglio fermarsi che
        // scrivere un archivio incoerente.
        throw StateError('Shard nel manifest ma assente: ${current.path}');
      }
      if (fnv1a64Hex(bytes) != current.checksum) {
        throw StateError('Shard corrotto: ${current.path}');
      }
      part = current.part;
      buffer = ShardCodec.decode(bytes);
    }

    return _fill(manifest, entity, records, month, now, part, buffer);
  }

  /// Scrive da zero gli shard di un'entità, senza rileggere niente: è l'export,
  /// dove si vuole un insieme nuovo e non un accodamento.
  Future<SyncManifest> writeFresh(
    SyncManifest manifest,
    String entity,
    List<SyncRecord> records,
    String month,
    DateTime now,
  ) {
    return _fill(manifest, entity, records, month, now, 1, <SyncRecord>[]);
  }

  Future<SyncManifest> _fill(
    SyncManifest manifest,
    String entity,
    List<SyncRecord> records,
    String month,
    DateTime now,
    int firstPart,
    List<SyncRecord> firstBuffer,
  ) async {
    var part = firstPart;
    var buffer = firstBuffer;
    var next = manifest;
    var bytes = ShardCodec.uncompressedBytes(buffer);

    for (final record in records) {
      final recordBytes = utf8.encode(record.toLine()).length + 1;
      if (buffer.isNotEmpty &&
          (buffer.length >= ShardCodec.maxRecordsPerShard ||
              bytes + recordBytes > ShardCodec.maxUncompressedBytes)) {
        next = await _flush(next, entity, month, part, buffer, now);
        part += 1;
        buffer = [];
        bytes = 0;
      }
      buffer.add(record);
      bytes += recordBytes;
    }
    return _flush(next, entity, month, part, buffer, now);
  }

  Future<SyncManifest> _flush(
    SyncManifest manifest,
    String entity,
    String month,
    int part,
    List<SyncRecord> records,
    DateTime now,
  ) async {
    if (records.isEmpty) return manifest;

    final bytes = ShardCodec.encode(records);
    final checksum = fnv1a64Hex(bytes);
    final logical =
        ShardCodec.shardPath(entity: entity, month: month, part: part);
    final path =
        _gateway is EncryptedSyncGateway ? '$logical.$checksum' : logical;
    await _gateway.write(path, bytes);

    return manifest.withEntry(
      ShardEntry(
        path: path,
        entity: entity,
        month: month,
        part: part,
        records: records.length,
        bytes: bytes.length,
        checksum: checksum,
        updatedAt: now,
      ),
    );
  }
}
