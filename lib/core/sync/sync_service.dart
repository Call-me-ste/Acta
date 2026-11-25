import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../database/database_files.dart';
import '../database/database_service.dart';
import '../database/entity_store.dart';
import 'drive_failure.dart';
import 'encrypted_sync_gateway.dart';
import 'hash.dart';
import 'shard_codec.dart';
import 'shard_writer.dart';
import 'sync_gateway.dart';
import 'sync_manifest.dart';
import 'sync_record.dart';
import 'sync_record_files.dart';

part 'sync_pending_records.dart';
part 'sync_changes.dart';
part 'sync_recovery.dart';
part 'sync_manifest_access.dart';

/// Sincronizza la coda locale con l'archivio remoto.
class SyncService {
  SyncService(this._db, {this.files});

  final DatabaseService _db;
  final SyncRecordFiles? files;
  SyncGateway? get activeGateway => _gateway;

  SyncGateway? _gateway;
  bool _isSyncing = false;
  int _appliedRevision = 0;
  Future<int>? _activeFullSync;
  Object? _lastError;
  DateTime? _lastSyncTime;
  String? _receiptKey;
  int? _remoteShardCount;

  static const String _cursorKey = 'remote_cursor';
  static const List<String> _entities = [
    'event',
    'todo',
    'note',
    'note_link',
    'note_folder',
  ];

  bool get isSyncing => _isSyncing;
  int get appliedRevision => _appliedRevision;
  String? get lastError => _lastError?.toString();
  Object? get lastFailure => _lastError;
  DateTime? get lastSyncTime => _awaitingReplay ? null : _lastSyncTime;
  int? get remoteShardCount => _awaitingReplay ? null : _remoteShardCount;
  bool get _awaitingReplay =>
      _db.meta.get(syncReplayKey) != _db.meta.get(_replayedKey);
  bool get hasArchiveBinding =>
      _db.meta.get(_ownerKey) != null ||
      _db.instance
          .select(
              "SELECT 1 FROM sync_meta WHERE key GLOB 'sync_receipt:*' LIMIT 1")
          .isNotEmpty;
  bool get isConfigured => _gateway != null;
  int get pendingCount => _db.outbox.pendingCount();

  void useGateway(SyncGateway? gateway, {String? accountKey}) =>
      _bindGateway(gateway, accountKey);

  SyncGateway _requireGateway() {
    final gateway = _gateway;
    if (gateway == null) {
      throw StateError(
        'Nessun gateway di sync configurato: chiama useGateway() prima di '
        'sincronizzare (finché non c\'è Google Drive, resta una cartella).',
      );
    }
    return gateway;
  }

  /// Spinge le operazioni in coda. Ritorna quante ne ha spedite.
  Future<int> pushPending() async {
    final gateway = _requireGateway();
    final rows = _db.outbox.pending();
    if (rows.isEmpty) return 0;
    if (gateway is EncryptedSyncGateway) return _pushChanges(gateway, rows);

    _isSyncing = true;
    var pushed = 0;
    try {
      var manifest = await _readManifest(gateway) ?? SyncManifest.empty();
      final writer = ShardWriter(gateway);
      final now = DateTime.now();
      final month = ShardCodec.monthKey(now);

      final rowsByEntity = <String, List<Row>>{};
      for (final row in rows) {
        rowsByEntity
            .putIfAbsent(row['entity_type'] as String, () => [])
            .add(row);
      }

      final synced = <String>[];
      for (final group in rowsByEntity.entries) {
        final prepared = await _prepare(gateway, group.value);
        if (prepared.isEmpty) continue;
        try {
          manifest = await writer.appendToCurrent(
            manifest,
            group.key,
            prepared.map((entry) => entry.record).toList(),
            month,
            now,
          );
          synced.addAll(prepared.map((entry) => entry.operation));
          pushed += prepared.length;
        } catch (error) {
          // Un'entità che fallisce non blocca le altre: si annota e si prosegue.
          // Le sue righe restano in coda e riprovano.
          _lastError = error;
          for (final entry in prepared) {
            _db.outbox.markFailed(entry.operation);
          }
        }
      }

      if (synced.isNotEmpty) {
        // Il manifest si scrive **prima** di dichiarare sincronizzato: se
        // fallisse qui, le operazioni resterebbero in coda invece di sparire.
        await _writeManifest(gateway, manifest);
        _db.runInTransaction(() => _db.outbox.markSynced(synced));
        _lastSyncTime = now;
        if (pushed == rows.length) _lastError = null;
      }
      return pushed;
    } finally {
      _isSyncing = false;
    }
  }

  /// Applica quello che c'è sul gateway. Ritorna quante entità ha cambiato.
  Future<int> pullChanges() => _pull();

  Future<int> _pull({void Function(SyncRecord)? observe}) async {
    final gateway = _requireGateway();
    final revision = _db.meta.get(syncReplayKey);
    final remote = await _readManifest(gateway);
    _checkReplayRevision(revision);
    if (gateway is EncryptedSyncGateway) {
      return _pullEncrypted(gateway, remote, revision, observe);
    }
    _remoteShardCount = remote?.shards.length ?? 0;
    if (remote == null) return 0;
    if (_db.meta.get(_cursorKey) == remote.cursor) return 0;
    return _apply(gateway, remote);
  }

  /// Applica tutto senza guardare il cursore: è l'import di un backup, che deve
  /// funzionare anche su un database vuoto.
  Future<int> importFrom(SyncGateway source) async {
    final manifest = await _readManifest(source);
    if (manifest == null) return 0;
    return _apply(source, manifest);
  }

  /// Scrive tutto l'archivio locale, in un insieme nuovo di shard, e sostituisce
  /// il manifest. Gli shard di prima che non servono più vengono cancellati:
  /// altrimenti ogni backup lascerebbe roba orfana che cresce.
  Future<int> exportTo(SyncGateway target) async {
    final previous = await _readManifest(target);
    final writer = ShardWriter(target);
    final now = DateTime.now();
    final month = ShardCodec.monthKey(now);
    var manifest = SyncManifest.empty();
    var total = 0;

    for (final entity in _entities) {
      final records = [
        for (final record in _localRecords(entity))
          await _prepareRecord(target, record),
      ];
      total += records.length;
      manifest = await writer.writeFresh(manifest, entity, records, month, now);
    }

    await _writeManifest(target, manifest);

    if (previous != null) {
      final keep = manifest.shards.map((entry) => entry.path).toSet();
      for (final shard in previous.shards) {
        if (!keep.contains(shard.path)) await target.delete(shard.path);
      }
    }
    return total;
  }

  Future<int> fullSync() async {
    final active = _activeFullSync;
    if (active != null) return active;
    final run = _fullSyncWithReceipt();
    _activeFullSync = run;
    try {
      return await run;
    } finally {
      _activeFullSync = null;
    }
  }

  // ─── Interni ──────────────────────────────────────────

  /// Applica un record se è più nuovo di quello che abbiamo. `true` se lo stato
  /// locale è cambiato.
  bool _applyRecord(SyncRecord record) {
    if (!EntityStore.isKnown(record.entity)) {
      // Famiglia che questa versione non conosce (arriverà da un client più
      // nuovo): si ignora invece di far fallire tutto il sync.
      return false;
    }

    final remoteClock = (
      record.version,
      record.updatedAt.millisecondsSinceEpoch,
    );
    final tombstone = 'deleted:${record.entity}:${record.id}';
    final deleted = _deletedClock(tombstone);
    final local = _newestClock(
        _db.entities.localClock(record.entity, record.id),
        _db.outbox.pendingClock(record.entity, record.id));

    if (record.operation == SyncOperation.delete) {
      if (deleted == null || _compare(deleted, remoteClock) < 0) {
        _db.meta.set(tombstone, '${remoteClock.$1},${remoteClock.$2}');
      }
      if (local != null && _compare(local, remoteClock) > 0) return false;
      if (!_db.entities.exists(record.entity, record.id)) return false;
      _db.entities.remove(record.entity, record.id);
      return true;
    }

    if (deleted != null && _compare(deleted, remoteClock) >= 0) return false;
    if (local != null) {
      final order = _compare(local, remoteClock);
      if (order > 0 || (order == 0 && _compareEqualClock(record) <= 0)) {
        return false;
      }
    }

    _db.entities.replace(record.entity, record.id, {
      ...record.data,
      'id': record.id,
      'version': record.version,
      'updated_at': record.updatedAt.millisecondsSinceEpoch,
    });
    files?.apply(record);
    return true;
  }

  int _compareEqualClock(SyncRecord record) {
    final row = _db.entities.rowById(record.entity, record.id);
    if (row == null) return 0;
    final fields = EntityStore.columnsFor(record.entity)
        .where((field) => record.data.containsKey(field))
        .toList()
      ..sort();
    final remote = jsonEncode([for (final field in fields) record.data[field]]);
    final local = jsonEncode([for (final field in fields) row[field]]);
    return remote.compareTo(local);
  }

  static (int, int)? _newestClock((int, int)? a, (int, int)? b) {
    if (a == null) return b;
    if (b == null) return a;
    return _compare(a, b) >= 0 ? a : b;
  }

  static int _compare((int, int) a, (int, int) b) {
    final byVersion = a.$1.compareTo(b.$1);
    return byVersion != 0 ? byVersion : a.$2.compareTo(b.$2);
  }
}
