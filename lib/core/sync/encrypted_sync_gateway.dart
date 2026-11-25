import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'sync_attachment_transport.dart';
import 'sync_gateway.dart';

class ArchiveRecoveryRequired extends StateError {
  ArchiveRecoveryRequired(super.message);
}

class DriveArchiveMissing extends StateError {
  DriveArchiveMissing() : super('L’archivio Drive non è più disponibile.');
}

class DriveArchiveIncompatible extends StateError {
  DriveArchiveIncompatible()
      : super('L’archivio Drive richiede una migrazione.');
}

class DriveArchiveDamaged extends StateError {
  DriveArchiveDamaged()
      : super('Parte dell’archivio Drive è assente o illeggibile.');
}

/// Encrypts compressed shard contents and the manifest before they reach the
/// gateway. Attachment files are already authenticated and encrypted on disk.
class EncryptedSyncGateway implements SyncGateway, SyncAttachmentTransport {
  EncryptedSyncGateway(this._gateway, SecretKey archiveKey)
      : _keys = _derive(archiveKey);

  final SyncGateway _gateway;
  final Future<(SecretKey, SecretKey)> _keys;
  final _cipher = AesGcm.with256bits();
  static const _prefix = 'encrypted-v1/data/';
  static const _blobPrefix = 'encrypted-v1/blob/';
  static const changesPrefix = 'encrypted-v1/changes/';
  static const _archiveMarker = 'encrypted-v1/archive';
  bool _initialized = false;

  static Future<bool> alreadyInitialized(SyncGateway gateway) async =>
      await gateway.read(_archiveMarker) != null;

  static Future<(SecretKey, SecretKey)> _derive(SecretKey key) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return (
      await hkdf.deriveKey(
          secretKey: key, info: utf8.encode('planner/sync/name/v1')),
      await hkdf.deriveKey(
          secretKey: key, info: utf8.encode('planner/sync/data/v1')),
    );
  }

  Future<String> _opaquePath(String path, String prefix) async {
    final mac = await Hmac.sha256().calculateMac(
      utf8.encode(prefix + path),
      secretKey: (await _keys).$1,
    );
    return prefix + base64Url.encode(mac.bytes).replaceAll('=', '');
  }

  Future<(String, List<int>)> _decode(String physical, List<int> bytes) async {
    final clear = await _cipher.decrypt(
      SecretBox.fromConcatenation(bytes,
          nonceLength: _cipher.nonceLength, macLength: 16),
      secretKey: (await _keys).$2,
      aad: utf8.encode(physical),
    );
    final separator = clear.indexOf(0);
    if (separator < 1) throw const FormatException('Oggetto sync non valido');
    return (
      utf8.decode(clear.sublist(0, separator)),
      clear.sublist(separator + 1)
    );
  }

  Future<String> changePath(List<int> bytes) async {
    final hash = await Sha256().hash(bytes);
    return _opaquePath(base64Url.encode(hash.bytes), changesPrefix);
  }

  Future<List<String>> listChanges() => _gateway.list(changesPrefix);

  Future<List<int>> readChange(String path) async {
    final sealed = await _gateway.read(path);
    if (sealed == null) throw DriveArchiveDamaged();
    try {
      final (name, clear) = await _decode(path, sealed);
      if (name != 'changes' || await changePath(clear) != path) {
        throw DriveArchiveDamaged();
      }
      return clear;
    } on SecretBoxAuthenticationError {
      throw DriveArchiveDamaged();
    } on FormatException {
      throw DriveArchiveDamaged();
    } on ArgumentError {
      throw DriveArchiveDamaged();
    }
  }

  Future<void> writeChange(String path, List<int> bytes) =>
      _seal(path, 'changes', bytes);

  Future<void> requireCompatibleArchive(String manifestPath,
      {bool requireExisting = false, void Function()? beforeInitialize}) async {
    // A repository with a plaintext manifest requires explicit migration.
    if (await _gateway.read(manifestPath) != null) {
      throw DriveArchiveIncompatible();
    }
    final marker = await _gateway.read(_archiveMarker);
    if (marker == null) {
      if (requireExisting ||
          (await listChanges()).isNotEmpty ||
          (await _gateway.list(_prefix)).isNotEmpty ||
          (await _gateway.list(_blobPrefix)).isNotEmpty) {
        throw DriveArchiveMissing();
      }
      beforeInitialize?.call();
      await _gateway.write(_archiveMarker, await _expectedMarker());
    } else {
      if (beforeInitialize != null) {
        throw StateError(
            'L’archivio Drive è tornato disponibile. Riprova la sincronizzazione.');
      }
      await _verifyMarker(marker);
    }
    _initialized = true;
  }

  Future<void> checkInitializedArchive() async {
    if (_initialized) await verifyExistingArchiveKey();
  }

  Future<void> verifyExistingArchiveKey() async {
    final marker = await _gateway.read(_archiveMarker);
    if (marker == null) {
      throw DriveArchiveMissing();
    }
    await _verifyMarker(marker);
  }

  Future<List<int>> _expectedMarker() async =>
      (await Hmac.sha256().calculateMac(
        utf8.encode('planner/sync/archive-key/v1'),
        secretKey: (await _keys).$1,
      ))
          .bytes;

  Future<void> _verifyMarker(List<int> marker) async {
    final expected = await _expectedMarker();
    if (marker.length != expected.length || Mac(marker) != Mac(expected)) {
      throw ArchiveRecoveryRequired(
          'La chiave appartiene a un archivio diverso.');
    }
  }

  @override
  Future<List<int>?> read(String path) async {
    final physical = await _opaquePath(path, _prefix);
    final bytes = await _gateway.read(physical);
    if (bytes == null) return null;
    final (name, clear) = await _decode(physical, bytes);
    if (name != path) {
      throw const FormatException('Nome oggetto sync non valido');
    }
    return clear;
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    if (path.isEmpty || path.contains('\u0000')) {
      throw ArgumentError.value(path);
    }
    final physical = await _opaquePath(path, _prefix);
    await _seal(physical, path, bytes);
  }

  Future<void> _seal(String physical, String name, List<int> bytes) async {
    final sealed = await _cipher.encrypt(
      [...utf8.encode(name), 0, ...bytes],
      secretKey: (await _keys).$2,
      aad: utf8.encode(physical),
    );
    await _gateway.write(physical, sealed.concatenation());
  }

  @override
  Future<List<String>> list(String prefix) async {
    final paths = <String>[];
    for (final physical in await _gateway.list(_prefix)) {
      final bytes = await _gateway.read(physical);
      if (bytes == null) continue;
      final (name, _) = await _decode(physical, bytes);
      if (name.startsWith(prefix)) paths.add(name);
    }
    return paths..sort();
  }

  @override
  Future<void> delete(String path) async =>
      _gateway.delete(await _opaquePath(path, _prefix));

  SyncAttachmentTransport get _transport {
    final gateway = _gateway;
    if (gateway is SyncAttachmentTransport) {
      return gateway as SyncAttachmentTransport;
    }
    throw UnsupportedError('Il gateway non supporta i file degli allegati');
  }

  @override
  Future<bool> hasAttachment(String path) async =>
      _transport.hasAttachment(await _opaquePath(path, _blobPrefix));

  @override
  Future<void> uploadAttachment(String path, File source) async =>
      _transport.uploadAttachment(await _opaquePath(path, _blobPrefix), source);

  @override
  Future<bool> downloadAttachment(String path, File target) async => _transport
      .downloadAttachment(await _opaquePath(path, _blobPrefix), target);
}
