part of 'sync_service.dart';

extension _SyncPendingRecords on SyncService {
  void _bindGateway(SyncGateway? gateway, String? accountKey) {
    if (gateway is EncryptedSyncGateway && accountKey != null) {
      checkArchiveAccount(accountKey);
      if (_db.meta.get(_ownerKey) == null) _db.meta.set(_ownerKey, accountKey);
    }
    _gateway = gateway;
    final key = accountKey == null ? null : 'sync_receipt:$accountKey';
    if (key == _receiptKey && gateway != null) return;
    _receiptKey = key;
    _lastError = null;
    final fields = (key == null ? null : _db.meta.get(key))?.split(',');
    _lastSyncTime = fields == null ? null : DateTime.tryParse(fields.first);
    _remoteShardCount = fields?.length == 2 ? int.tryParse(fields!.last) : null;
  }

  Future<int> _fullSyncWithReceipt() async {
    final revision = _db.meta.get(syncReplayKey);
    if (revision != _db.meta.get(_replayedKey)) {
      _lastSyncTime = null;
      _remoteShardCount = null;
    }
    final previous = _lastSyncTime;
    _lastError = null;
    try {
      if (_gateway case final EncryptedSyncGateway gateway) {
        await gateway.checkInitializedArchive();
      }
      var pulled =
          _gateway is EncryptedSyncGateway ? await _pullBeforePush() : 0;
      _checkReplayRevision(revision);
      await pushPending();
      final pushError = _lastError;
      pulled += await pullChanges();
      _checkReplayRevision(revision);
      _lastError = pushError;
      if (pushError != null) {
        _lastSyncTime = previous;
        return pulled;
      }
      final verifiedAt = DateTime.now();
      _lastSyncTime = verifiedAt;
      final key = _receiptKey;
      if (key != null) {
        _db.meta.set(key, '${verifiedAt.toIso8601String()},$_remoteShardCount');
      }
      return pulled;
    } catch (_) {
      _lastSyncTime = _db.meta.get(syncReplayKey) == revision ? previous : null;
      rethrow;
    }
  }

  Future<SyncRecord> _prepareRecord(SyncGateway gateway, SyncRecord record) =>
      files?.prepare(gateway, record) ?? Future.value(record);

  Future<List<({String operation, SyncRecord record})>> _prepare(
    SyncGateway gateway,
    List<Row> rows, {
    void Function()? check,
  }) async {
    final result = <({String operation, SyncRecord record})>[];
    final blocked = <String>{};
    for (final row in rows) {
      final operation = row['operation_id'] as String;
      final record = SyncRecord.fromOutboxRow(row);
      final entity = '${record.entity}:${record.id}';
      if (blocked.contains(entity)) continue;
      try {
        result.add((
          operation: operation,
          record: await _prepareRecord(gateway, record)
        ));
      } catch (error) {
        check?.call();
        blocked.add(entity);
        _lastError = error;
        _db.outbox.markFailed(operation);
        if (error is DriveFailure ||
            error is SocketException ||
            error is TimeoutException) {
          rethrow;
        }
      }
      check?.call();
    }
    return result;
  }
}
