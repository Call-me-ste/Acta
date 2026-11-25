import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Versioned, bounded-memory envelope for private attachment files.
///
/// Each file gets a random HKDF salt. The frame number is the nonce under
/// that file's derived key. The header and logical identity are authenticated
/// on every frame, including the frame for an empty file.
class EncryptedFileCodec {
  EncryptedFileCodec(this._key);

  final SecretKey _key;
  final _cipher = AesGcm.with256bits();
  static const blockSize = 256 * 1024;
  static const _headerSize = 44;
  static const _tagSize = 16;
  static const _magic = [80, 76, 65, 1];

  Future<void> encrypt(File source, File target, {required String identity}) =>
      _convert(source, target, identity, encrypting: true);

  Future<void> decrypt(File source, File target, {required String identity}) =>
      _convert(source, target, identity, encrypting: false);

  Future<void> verify(File source, {required String identity}) async {
    final input = await source.open();
    try {
      await _process(input, null, identity, encrypting: false);
    } finally {
      await input.close();
    }
  }

  Future<void> _convert(
    File source,
    File target,
    String identity, {
    required bool encrypting,
  }) async {
    final stage = await target.parent.createTemp('.planner-');
    final stagedFile = File.fromUri(stage.uri.resolve('data'));
    try {
      final input = await source.open();
      try {
        final output = await stagedFile.open(mode: FileMode.writeOnly);
        try {
          await _process(input, output, identity, encrypting: encrypting);
          await output.flush();
        } finally {
          await output.close();
        }
      } finally {
        await input.close();
      }
      await stagedFile.rename(target.path);
    } finally {
      if (await stagedFile.exists()) await stagedFile.delete();
      await stage.delete();
    }
  }

  Future<void> _process(
    RandomAccessFile input,
    RandomAccessFile? output,
    String identity, {
    required bool encrypting,
  }) async {
    final inputLength = await input.length();
    final header =
        encrypting ? _newHeader(inputLength) : await input.read(_headerSize);
    if (header.length != _headerSize ||
        List.generate(_magic.length, (i) => header[i] == _magic[i])
            .contains(false)) {
      throw const FormatException('Formato del file cifrato non riconosciuto');
    }
    final length = ByteData.sublistView(header).getUint64(36);
    if (length < 0 || length > inputLength) {
      throw const FormatException('Dimensione del file cifrato non valida');
    }
    final frames = max(1, (length + blockSize - 1) ~/ blockSize);
    if (!encrypting &&
        inputLength != _headerSize + length + frames * _tagSize) {
      throw const FormatException('Dimensione del file cifrato non valida');
    }
    final key = await Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    ).deriveKey(
      secretKey: _key,
      nonce: Uint8List.sublistView(header, 4, 36),
      info: utf8.encode('planner/attachment/v1'),
    );
    final aad = [...header, ...utf8.encode(identity)];
    if (encrypting) await output!.writeFrom(header);
    for (var frame = 0; frame < frames; frame++) {
      final size = min(blockSize, length - frame * blockSize);
      final storedSize = encrypting ? size : size + _tagSize;
      final bytes = await input.read(storedSize);
      if (bytes.length != storedSize) {
        throw const FormatException('File troncato durante la lettura');
      }
      final nonce = Uint8List(12);
      ByteData.sublistView(nonce).setUint64(4, frame);
      if (encrypting) {
        final box = await _cipher.encrypt(bytes,
            secretKey: key, nonce: nonce, aad: aad);
        await output!.writeFrom(box.cipherText);
        await output.writeFrom(box.mac.bytes);
      } else {
        final box = SecretBox(
          Uint8List.sublistView(bytes, 0, size),
          nonce: nonce,
          mac: Mac(Uint8List.sublistView(bytes, size)),
        );
        final plaintext = await _cipher.decrypt(box, secretKey: key, aad: aad);
        if (output != null) await output.writeFrom(plaintext);
      }
    }
    if (await input.readByte() != -1) {
      throw const FormatException('Il file è cambiato durante la lettura');
    }
  }

  Uint8List _newHeader(int length) {
    final header = Uint8List(_headerSize);
    header.setRange(0, 4, _magic);
    final random = Random.secure();
    for (var i = 4; i < 36; i++) {
      header[i] = random.nextInt(256);
    }
    ByteData.sublistView(header).setUint64(36, length);
    return header;
  }
}
