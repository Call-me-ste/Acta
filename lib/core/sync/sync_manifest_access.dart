part of 'sync_service.dart';

extension _SyncManifestAccess on SyncService {
  Future<int> _apply(SyncGateway gateway, SyncManifest manifest,
      {void Function(SyncRecord)? observe}) async {
    final revision = _db.meta.get(syncReplayKey);
    _isSyncing = true;
    var applied = 0;
    try {
      for (final shard in manifest.shards) {
        if (observe == null &&
            _db.meta.get('shard:${shard.path}') == shard.checksum) {
          continue;
        }

        final bytes = await gateway.read(shard.path);
        _checkReplayRevision(revision);
        if (bytes == null) {
          throw StateError('Shard nel manifest ma assente: ${shard.path}');
        }
        // Integrità **prima** di applicare: o lo shard entra intero, o non entra.
        if (fnv1a64Hex(bytes) != shard.checksum) {
          throw StateError('Shard corrotto: ${shard.path}');
        }
        final records = ShardCodec.decode(bytes);
        if (records.length != shard.records) {
          throw StateError('Conteggio record non coerente: ${shard.path}');
        }

        final before = applied;
        _db.runInTransaction(() {
          for (final record in records) {
            observe?.call(record);
            if (_applyRecord(record)) applied += 1;
          }
          _db.meta.set('shard:${shard.path}', shard.checksum);
        });
        if (applied != before) _appliedRevision++;
      }

      _db.meta.set(SyncService._cursorKey, manifest.cursor);
      _lastSyncTime = DateTime.now();
      _lastError = null;
      return applied;
    } catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  Future<SyncManifest?> _readManifest(SyncGateway gateway) async {
    final bytes = await gateway.read(SyncManifest.filePath);
    return bytes == null ? null : SyncManifest.decode(bytes);
  }

  Future<void> _writeManifest(SyncGateway gateway, SyncManifest manifest) {
    return gateway.write(SyncManifest.filePath, manifest.encode());
  }
}
