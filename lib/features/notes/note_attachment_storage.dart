part of 'note_attachment_store.dart';

String remoteAttachmentPath(String name) => 'attachments/$name';

Future<void> _verifyDownloaded(List<int> key, String path, String name) =>
    Isolate.run(() =>
        EncryptedFileCodec(SecretKey(key)).verify(File(path), identity: name));

extension NoteAttachmentStorage on NoteAttachmentStore {
  Future<String> recoveryCode() async {
    final bytes = await (await existingArchiveKey()).extractBytes();
    return 'PLANNER1-${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  Future<bool> recoveryCopyConfirmed() async {
    final code = await recoveryCode();
    final fingerprint = await _recoveryFingerprint(code);
    return await const FlutterSecureStorage().read(key: _confirmedSlot) ==
        fingerprint;
  }

  Future<void> confirmRecoveryCopy(String code) async {
    final current = await recoveryCode();
    if (current != code.trim()) {
      throw const FormatException(
          'La copia non coincide con la chiave di Acta.');
    }
    await const FlutterSecureStorage().write(
      key: _confirmedSlot,
      value: await _recoveryFingerprint(current),
    );
  }

  Future<void> useRecoveryCode(
    String code, {
    required Future<void> Function(SecretKey key) verify,
  }) async {
    final match =
        RegExp(r'^PLANNER1-([A-Za-z0-9_-]{43})$').firstMatch(code.trim());
    if (match == null) {
      throw const FormatException('Codice di recupero non valido');
    }
    final bytes = base64Url.decode('${match.group(1)}=');
    final key = base64Url.encode(bytes);
    if (key != '${match.group(1)}=') {
      throw const FormatException('Chiave di recupero non valida.');
    }
    final candidate = SecretKey(bytes);
    await verify(candidate);
    const storage = FlutterSecureStorage();
    if (_readKey != null || _keyFuture != null) {
      if (await recoveryCode() == code.trim()) return;
      throw StateError('Sul dispositivo è già attiva un’altra chiave di Acta.');
    }
    final pending = () async {
      final existing = await storage.read(key: NoteAttachmentStore._keySlot);
      if (existing != null) {
        if (existing == key) return candidate;
        throw StateError(
            'Sul dispositivo è già attiva un’altra chiave di Acta.');
      }
      await _verifyLocalAttachmentKey(candidate);
      await storage.write(key: NoteAttachmentStore._keySlot, value: key);
      return candidate;
    }();
    _keyFuture = pending;
    try {
      await pending;
    } catch (_) {
      if (identical(_keyFuture, pending)) _keyFuture = null;
      rethrow;
    }
  }

  Future<void> _verifyLocalAttachmentKey(SecretKey key) async {
    final rows = _database.instance.select(
      'SELECT id, note_id, blob_id, metadata FROM note_attachments LIMIT 1',
    );
    if (rows.isEmpty) return;
    final row = rows.single;
    final box = SecretBox.fromConcatenation(
      row['metadata'] as Uint8List,
      nonceLength: _cipher.nonceLength,
      macLength: 16,
    );
    try {
      await _cipher.decrypt(
        box,
        secretKey: key,
        aad: NoteAttachmentStore._metadataIdentity(
          row['note_id'] as String,
          row['id'] as String,
          row['blob_id'] as String,
        ),
      );
    } on SecretBoxAuthenticationError {
      throw StateError(
          'La chiave appartiene a un archivio diverso da quello degli allegati su questo dispositivo.');
    }
  }

  Future<SecretKey> existingArchiveKey() async {
    if (_readKey != null || _keyFuture != null) return _key();
    const storage = FlutterSecureStorage();
    final existing = await storage.read(key: NoteAttachmentStore._keySlot);
    if (existing == null) {
      throw StateError('Inserisci prima la chiave di recupero della copia.');
    }
    return _key();
  }

  File blobFile(String name) {
    if (!RegExp(r'^[a-f0-9]{64}\.(blob|thumb)$').hasMatch(name)) {
      throw const FormatException('Identificativo allegato non valido');
    }
    return File(paths.join(_root.path, name));
  }

  Future<void> _download(SyncAttachmentTransport transport, String name) async {
    final pending = _downloads.putIfAbsent(name, () async {
      await _root.create(recursive: true);
      final work = await _root.createTemp('.download-');
      try {
        final staged = File(paths.join(work.path, 'encrypted'));
        if (!await transport.downloadAttachment(
            remoteAttachmentPath(name), staged)) {
          return;
        }
        final key = await (await _key()).extractBytes();
        await _verifyDownloaded(key, staged.path, name);
        await staged.rename(blobFile(name).path);
      } finally {
        await work.delete(recursive: true);
      }
    });
    try {
      await pending;
    } finally {
      if (identical(_downloads[name], pending)) _downloads.remove(name);
    }
  }
}

const _confirmedSlot = 'planner.recovery.verified.v1';

Future<String> _recoveryFingerprint(String code) async =>
    base64Url.encode((await Sha256().hash(utf8.encode(code))).bytes);
