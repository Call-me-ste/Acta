import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as paths;
import 'package:uuid/uuid.dart';

import '../../core/database/database_service.dart';
import '../../core/sync/encrypted_file_codec.dart';
import '../../core/sync/sync_attachment_transport.dart';
import 'note_attachment_image.dart';

part 'note_attachment_storage.dart';

enum NoteAttachmentKind { photo, pdf }

class NoteAttachment {
  const NoteAttachment(this.id, this.noteId, this.blobId, this.name, this.kind);

  final String id;
  final String noteId;
  final String blobId;
  final String name;
  final NoteAttachmentKind kind;
}

class NoteAttachmentStore {
  NoteAttachmentStore(
    this._database,
    this._root, {
    Future<SecretKey> Function()? readKey,
    this.remote,
  }) : _readKey = readKey;

  final DatabaseService _database;
  final Directory _root;
  final Future<SecretKey> Function()? _readKey;
  final SyncAttachmentTransport? Function()? remote;
  final _downloads = <String, Future<void>>{};
  Future<SecretKey>? _keyFuture;
  final _cipher = AesGcm.with256bits();

  static const _keySlot = 'planner.note-attachments.v1';
  static const maxPhotoBytes = 18 * 1024 * 1024;
  static const maxPdfBytes = 100 * 1024 * 1024;

  Future<SecretKey> archiveKey() => _key();

  Future<SecretKey> _loadDeviceKey() async {
    const storage = FlutterSecureStorage();
    final value = await storage.read(key: _keySlot);
    if (value != null) {
      final bytes = base64Url.decode(value);
      if (bytes.length != 32) throw const FormatException('Chiave non valida');
      return SecretKey(bytes);
    }
    if (_database.instance
        .select('SELECT 1 FROM note_attachments LIMIT 1')
        .isNotEmpty) {
      throw StateError(
          'Chiave degli allegati non disponibile su questo dispositivo');
    }
    final key = await AesGcm.with256bits().newSecretKey();
    await storage.write(
      key: _keySlot,
      value: base64Url.encode(await key.extractBytes()),
    );
    return key;
  }

  Future<SecretKey> _key() async {
    final pending = _keyFuture ??= (_readKey ?? _loadDeviceKey)();
    try {
      return await pending;
    } catch (_) {
      if (identical(_keyFuture, pending)) _keyFuture = null;
      rethrow;
    }
  }

  Future<NoteAttachment> importFile(
    File source, {
    required String noteId,
    required String name,
    required NoteAttachmentKind kind,
    Uint8List? pdfThumbnail,
  }) async {
    final key = await _key();
    final keyBytes = await key.extractBytes();
    final job = (
      source: source.path,
      root: _root.path,
      key: keyBytes,
      kind: kind,
      preview: pdfThumbnail
    );
    final blobId = await Isolate.run(() => _import(job));
    final id = const Uuid().v4();
    final record = NoteAttachment(id, noteId, blobId, _cleanName(name), kind);
    final metadata = await _encode(record);
    _database.instance.execute(
      'INSERT INTO note_attachments (id, note_id, blob_id, metadata) '
      'VALUES (?, ?, ?, ?)',
      [id, noteId, blobId, metadata],
    );
    return record;
  }

  Future<NoteAttachment?> read(String noteId, String id) async {
    final rows = _database.instance.select(
      'SELECT blob_id, metadata FROM note_attachments WHERE note_id = ? AND id = ?',
      [noteId, id],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final blobId = row['blob_id'] as String;
    final box = SecretBox.fromConcatenation(
      row['metadata'] as Uint8List,
      nonceLength: _cipher.nonceLength,
      macLength: 16,
    );
    final clear = await _cipher.decrypt(
      box,
      secretKey: await _key(),
      aad: _metadataIdentity(noteId, id, blobId),
    );
    final fields = jsonDecode(utf8.decode(clear)) as List<dynamic>;
    return NoteAttachment(
      id,
      noteId,
      blobId,
      fields[0] as String,
      NoteAttachmentKind.values.byName(fields[1] as String),
    );
  }

  Future<NoteAttachment> rename(NoteAttachment attachment, String name) async {
    final changed = NoteAttachment(
      attachment.id,
      attachment.noteId,
      attachment.blobId,
      _cleanName(name),
      attachment.kind,
    );
    _database.instance.execute(
      'UPDATE note_attachments SET metadata = ? WHERE note_id = ? AND id = ?',
      [await _encode(changed), changed.noteId, changed.id],
    );
    return changed;
  }

  Future<File> open(
    NoteAttachment attachment,
    Directory workingDirectory, {
    bool thumbnail = false,
  }) async {
    final suffix = thumbnail ? '.thumb' : '.blob';
    final id = attachment.blobId;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(id)) {
      throw const FormatException('Identificativo allegato non valido');
    }
    final key = await _key();
    final keyBytes = await key.extractBytes();
    final source = blobFile(id + suffix);
    final transport = remote?.call();
    if (transport != null && !await source.exists()) {
      await _download(transport, id + suffix);
    }
    if (!await source.exists()) throw const AttachmentUnavailable();
    final file = File(paths.join(workingDirectory.path,
        attachment.kind == NoteAttachmentKind.pdf ? 'document.pdf' : 'photo'));
    final sourcePath = source.path;
    final target = file.path;
    final identity = id + suffix;
    await Isolate.run(() => EncryptedFileCodec(SecretKey(keyBytes)).decrypt(
          File(sourcePath),
          File(target),
          identity: identity,
        ));
    return file;
  }

  Future<Uint8List> _encode(NoteAttachment attachment) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode([attachment.name, attachment.kind.name])),
      secretKey: await _key(),
      aad: _metadataIdentity(
          attachment.noteId, attachment.id, attachment.blobId),
    );
    return box.concatenation();
  }

  static List<int> _metadataIdentity(String note, String id, String blob) =>
      utf8.encode(
          jsonEncode(['planner/attachment-metadata/v1', note, id, blob]));

  static String _cleanName(String name) {
    final clean = name.replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_').trim();
    if (clean.isEmpty) return 'Allegato';
    return String.fromCharCodes(clean.runes.take(180));
  }
}

class AttachmentUnavailable implements Exception {
  const AttachmentUnavailable();
}

Future<String> _import(
  ({
    String source,
    String root,
    List<int> key,
    NoteAttachmentKind kind,
    Uint8List? preview
  }) job,
) async {
  final source = File(job.source);
  final pdf = job.kind == NoteAttachmentKind.pdf;
  final size = await source.length();
  if (size == 0) {
    throw FormatException(pdf ? 'Il PDF è vuoto.' : 'La foto è vuota.');
  }
  if (size >
      (pdf
          ? NoteAttachmentStore.maxPdfBytes
          : NoteAttachmentStore.maxPhotoBytes)) {
    throw FormatException(pdf
        ? 'Il PDF supera il limite di 100 MiB.'
        : 'La foto supera il limite di 18 MiB.');
  }
  if (pdf) {
    final header = await source.openRead(0, size < 1024 ? size : 1024).first;
    if (!latin1.decode(header).contains('%PDF-')) {
      throw const FormatException('Il file selezionato non è un PDF');
    }
  }
  final root = Directory(job.root);
  await root.create(recursive: true);
  final preview = job.preview;
  final hasPreview = preview != null && preview.length < 2 * 1024 * 1024;
  final temp = pdf && !hasPreview ? null : await root.createTemp('.import-');
  try {
    var original = source;
    File? thumb;
    if (!pdf && temp != null) {
      final prepared = prepareAttachmentImage(source.path);
      original = await File(paths.join(temp.path, 'original'))
          .writeAsBytes(prepared.photo);
      thumb = await File(paths.join(temp.path, 'thumb'))
          .writeAsBytes(prepared.thumbnail);
    } else if (hasPreview && temp != null) {
      thumb = await File(paths.join(temp.path, 'thumb')).writeAsBytes(preview);
    }
    final key = SecretKey(job.key);
    final digest = Sha256().newHashSink();
    await for (final bytes in original.openRead()) {
      digest.add(bytes);
    }
    digest.close();
    final mac = await Hmac.sha256().calculateMac(
      [
        ...utf8.encode('planner/blob-id/v1/${job.kind.name}/'),
        ...(await digest.hash()).bytes
      ],
      secretKey: key,
    );
    final id =
        mac.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final codec = EncryptedFileCodec(key);
    final originalTarget = File(paths.join(root.path, '$id.blob'));
    if (!await originalTarget.exists()) {
      await codec.encrypt(original, originalTarget, identity: '$id.blob');
    }
    if (thumb != null) {
      final thumbnailTarget = File(paths.join(root.path, '$id.thumb'));
      if (!await thumbnailTarget.exists()) {
        await codec.encrypt(thumb, thumbnailTarget, identity: '$id.thumb');
      }
    }
    return id;
  } finally {
    if (temp != null) await temp.delete(recursive: true);
  }
}
