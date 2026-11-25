part of 'sync_service.dart';

extension _SyncChanges on SyncService {
  (int, int)? _deletedClock(String key) {
    final value = _db.meta.get(key);
    if (value == null) return null;
    final parts = value.split(',');
    return (int.parse(parts.first), int.parse(parts.last));
  }

  // Each write owns its own content-addressed file. Two devices can publish
  // concurrently without either having to rewrite a shared index.
  Future<int> _pushChanges(EncryptedSyncGateway gateway, List<Row> rows) async {
    final revision = _db.meta.get(syncReplayKey);
    _isSyncing = true;
    try {
      final latest = <(String, String), Row>{};
      final operations = <(String, String), List<String>>{};
      for (final row in rows) {
        final id = (row['entity_type'] as String, row['entity_id'] as String);
        latest[id] = row;
        (operations[id] ??= []).add(row['operation_id'] as String);
      }
      final prepared = await _prepare(gateway, latest.values.toList(),
          check: () => _checkReplayRevision(revision));
      var pushed = 0;
      var size = 0;
      final batch = <({String operation, SyncRecord record})>[];

      Future<void> flush() async {
        if (batch.isEmpty) return;
        final bytes =
            ShardCodec.encode(batch.map((entry) => entry.record).toList());
        final path = await gateway.changePath(bytes);
        _checkReplayRevision(revision);
        await gateway.writeChange(path, bytes);
        await gateway.readChange(path);
        _checkReplayRevision(revision);
        final acknowledged = [
          for (final entry in batch)
            ...operations[(entry.record.entity, entry.record.id)]!,
        ];
        _db.runInTransaction(() => _db.outbox.markSynced(acknowledged));
        pushed += acknowledged.length;
        batch.clear();
        size = 0;
      }

      for (final entry in prepared) {
        final recordSize = utf8.encode(entry.record.toLine()).length + 1;
        if (batch.isNotEmpty &&
            (batch.length >= ShardCodec.maxRecordsPerShard ||
                size + recordSize > ShardCodec.maxUncompressedBytes)) {
          await flush();
        }
        batch.add(entry);
        size += recordSize;
      }
      await flush();
      return pushed;
    } finally {
      _isSyncing = false;
    }
  }

  Future<int> _pullEncrypted(EncryptedSyncGateway gateway, SyncManifest? legacy,
      String? revision, void Function(SyncRecord)? observe) async {
    var applied = 0;
    if (legacy != null &&
        (observe != null ||
            _db.meta.get(SyncService._cursorKey) != legacy.cursor)) {
      applied = await _apply(gateway, legacy, observe: observe);
    }
    final paths = await gateway.listChanges();
    _checkReplayRevision(revision);
    _isSyncing = true;
    try {
      for (final path in paths) {
        final marker = 'applied:$path';
        if (observe == null && _db.meta.get(marker) != null) continue;
        final records = ShardCodec.decode(await gateway.readChange(path));
        _checkReplayRevision(revision);
        final before = applied;
        _db.runInTransaction(() {
          for (final record in records) {
            observe?.call(record);
            if (_applyRecord(record)) applied++;
          }
          _db.meta.set(marker, '1');
        });
        if (applied != before) _appliedRevision++;
      }
      _remoteShardCount = (legacy?.shards.length ?? 0) + paths.length;
      return applied;
    } finally {
      _isSyncing = false;
    }
  }
}
