part of 'sync_service.dart';

const _ownerKey = 'sync_archive_owner';
const _bootstrapKey = 'sync_bootstrap_v1';
const _replayedKey = 'sync_replay_done';

class ArchiveAccountMismatch extends StateError {
  ArchiveAccountMismatch()
      : super(
            'Questo archivio locale è già associato a un altro account Google. '
            'Scollega questo account e ricollega quello originale.');
}

extension SyncRecovery on SyncService {
  void enqueueForNewArchive(String account) {
    checkArchiveAccount(account);
    _db.runInTransaction(() {
      _db.dimenticaStatoDiSync();
      _db.instance.execute(
          'DELETE FROM sync_meta WHERE key = ?', ['sync_receipt:$account']);
      for (final entity in EntityStore.kinds) {
        for (final record in _localRecords(entity)) {
          if (entity == 'palette' && record.data['is_preset'] == 1) continue;
          if (_db.outbox.pendingClock(entity, record.id) == null) {
            _enqueueExisting(record);
          }
        }
      }
      for (final row in _db.instance.select(
        "SELECT key, value FROM sync_meta WHERE key GLOB 'deleted:*'",
      )) {
        final key = row['key'] as String;
        final separator = key.indexOf(':', 'deleted:'.length);
        if (separator < 0) continue;
        final entity = key.substring('deleted:'.length, separator);
        final id = key.substring(separator + 1);
        if (!EntityStore.isKnown(entity) ||
            _db.entities.exists(entity, id) ||
            _db.outbox.pendingClock(entity, id) != null) {
          continue;
        }
        final clock = _deletedClock(key)!;
        _enqueueExisting(SyncRecord(
          entity: entity,
          id: id,
          operation: SyncOperation.delete,
          version: clock.$1,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(clock.$2),
          data: const {},
        ));
      }
    });
  }

  void checkArchiveAccount(String? account) {
    if (account == null) return;
    final owner = _db.meta.get(_ownerKey);
    if (owner == account) return;
    final previous = _db.instance.select(
      'SELECT substr(key, 14) AS account FROM sync_meta '
      "WHERE key GLOB 'sync_receipt:*'",
    );
    if (owner != null || previous.any((row) => row['account'] != account)) {
      throw ArchiveAccountMismatch();
    }
  }

  Future<int> recoverRemote() async {
    final gateway = _requireGateway();
    if (gateway is! EncryptedSyncGateway) {
      throw StateError('Collega prima l’archivio cifrato di Google Drive.');
    }
    await gateway.verifyExistingArchiveKey();
    if (_activeFullSync != null) {
      throw StateError('Attendi la fine della sincronizzazione e riprova.');
    }
    _db.runInTransaction(_db.dimenticaStatoDiSync);
    return fullSync();
  }

  Future<int> _pullBeforePush() async {
    final revision = _db.meta.get(syncReplayKey);
    final needsReplay = revision != _db.meta.get(_replayedKey);
    final account = _db.meta.get(_ownerKey);
    final bootstrap = account != null && _db.meta.get(_bootstrapKey) != account;
    if (!bootstrap && !needsReplay) return 0;

    final candidates = <(String, String), SyncRecord>{
      if (bootstrap)
        for (final entity in EntityStore.kinds)
          for (final record in _localRecords(entity, missingOutbox: true))
            if (entity != 'palette' || record.data['is_preset'] != 1)
              (record.entity, record.id): record,
    };

    void observe(SyncRecord remote) {
      final id = (remote.entity, remote.id);
      final local = candidates[id];
      if (local == null) return;
      final order =
          SyncService._compare(_recordClock(remote), _recordClock(local));
      if (order > 0 ||
          (order == 0 &&
              (remote.operation == SyncOperation.delete ||
                  _compareEqualClock(remote) >= 0))) {
        candidates.remove(id);
      }
    }

    final pulled = await _pull(observe: candidates.isEmpty ? null : observe);
    _checkReplayRevision(revision);
    _db.runInTransaction(() {
      for (final record in candidates.values) {
        final clock = _recordClock(record);
        if (_db.entities.localClock(record.entity, record.id) != clock ||
            _db.outbox.pendingClock(record.entity, record.id) != null) {
          continue;
        }
        final deleted = _deletedClock('deleted:${record.entity}:${record.id}');
        if (deleted != null && SyncService._compare(deleted, clock) >= 0) {
          continue;
        }
        _enqueueExisting(record);
      }
      if (bootstrap) _db.meta.set(_bootstrapKey, account);
      if (revision != null) _db.meta.set(_replayedKey, revision);
    });
    return pulled;
  }

  void _enqueueExisting(SyncRecord record) => _db.outbox.enqueue(
        operationId: const Uuid().v4(),
        entity: record.entity,
        entityId: record.id,
        operation: record.operation.name,
        version: record.version,
        updatedAt: record.updatedAt.millisecondsSinceEpoch,
        payload: record.data,
      );

  List<SyncRecord> _localRecords(String entity, {bool missingOutbox = false}) {
    final columns = EntityStore.columnsFor(entity);
    final rows = missingOutbox
        ? _db.entities.rowsWithoutOutbox(entity)
        : _db.entities.allRows(entity);
    return rows.map((row) {
      final data = <String, Object?>{};
      for (final column in columns) {
        if (row.containsKey(column)) data[column] = row[column];
      }
      return SyncRecord(
        entity: entity,
        id: row['id'] as String,
        operation: SyncOperation.upsert,
        version: (row['version'] as int?) ?? 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['updated_at'] as int?) ?? 0,
        ),
        data: data,
      );
    }).toList();
  }

  void _checkReplayRevision(String? revision) {
    if (_db.meta.get(syncReplayKey) != revision) {
      throw StateError(
          'I dati locali sono stati ripristinati. Riprova la sincronizzazione.');
    }
  }
}

(int, int) _recordClock(SyncRecord record) =>
    (record.version, record.updatedAt.millisecondsSinceEpoch);
