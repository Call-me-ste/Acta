part of 'drive_sync_gateway.dart';

const _transferBlock = 2 * 1024 * 1024;
const _maximumEncryptedAttachmentSize = 110 * 1024 * 1024;

extension _DriveAttachmentTransfer on DriveSyncGateway {
  Future<String?> _findAttachment(String path) async {
    final cached = _attachmentIds[path];
    if (cached != null) return cached;
    final name = DriveSyncGateway._encode(path)
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'");
    final url = Uri.parse(DriveSyncGateway._apiRoot).replace(queryParameters: {
      'spaces': 'appDataFolder',
      'q': "trashed = false and name = '$name'",
      'fields': 'files(id,name)',
      'pageSize': '2',
    });
    final response = await _send('GET', url);
    _require(response);
    final files =
        (jsonDecode(response.bodyText) as Map)['files'] as List? ?? [];
    if (files.isEmpty) return null;
    final id = (files.first as Map)['id'] as String;
    return _attachmentIds[path] = id;
  }

  Future<void> _upload(String path, File source) async {
    final length = await source.length();
    _checkSize(length);
    var session = _uploadSessions[path];
    var position = 0;
    if (session != null) {
      final response = await _queryUpload(session, length);
      if (response.isSuccess) {
        _finishUpload(path, response);
        return;
      }
      if (response.statusCode == 404 || response.statusCode == 410) {
        _uploadSessions.remove(path);
        session = null;
      } else {
        if (response.statusCode >= 400 && response.statusCode < 500) {
          _uploadSessions.remove(path);
        }
        position = _uploadPosition(response, length);
      }
    }
    session ??= await _startUpload(path, length);
    final file = await source.open();
    try {
      while (position < length) {
        await file.setPosition(position);
        final remaining = length - position;
        final bytes = await file
            .read(remaining < _transferBlock ? remaining : _transferBlock);
        if (bytes.isEmpty) {
          throw const FormatException('Allegato troncato durante l’upload');
        }
        final response = await _send(
          'PUT',
          session,
          body: bytes,
          contentType: 'application/octet-stream',
          headers: {
            'Content-Range':
                'bytes $position-${position + bytes.length - 1}/$length'
          },
        );
        if (response.isSuccess) {
          if (position + bytes.length != length) {
            throw const FormatException(
                'Drive ha terminato un upload parziale');
          }
          _finishUpload(path, response);
          return;
        }
        if (response.statusCode >= 400 && response.statusCode < 500) {
          _uploadSessions.remove(path);
        }
        final next = _uploadPosition(response, length);
        if (next <= position) throw StateError('Upload interrotto: riprovare');
        position = next;
      }
      final response = await _queryUpload(session, length);
      _require(response);
      _finishUpload(path, response);
    } finally {
      await file.close();
    }
  }

  Future<Uri> _startUpload(String path, int length) async {
    final response = await _send(
      'POST',
      Uri.parse(
          '${DriveSyncGateway._uploadRoot}?uploadType=resumable&fields=id'),
      body: utf8.encode(jsonEncode({
        'name': DriveSyncGateway._encode(path),
        'parents': ['appDataFolder'],
      })),
      contentType: 'application/json; charset=utf-8',
      headers: {
        'X-Upload-Content-Type': 'application/octet-stream',
        'X-Upload-Content-Length': '$length',
      },
    );
    _require(response);
    final uri = Uri.tryParse(response.headers['location'] ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'www.googleapis.com' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        !uri.path.startsWith('/upload/drive/')) {
      throw const FormatException('Sessione Drive non valida');
    }
    return _uploadSessions[path] = uri;
  }

  Future<DriveHttpResponse> _queryUpload(Uri session, int length) => _send(
        'PUT',
        session,
        body: const <int>[],
        headers: {'Content-Range': 'bytes */$length'},
      );

  int _uploadPosition(DriveHttpResponse response, int length) {
    if (response.statusCode != 308) {
      _require(response);
    }
    final range = response.headers['range'];
    if (range == null) return 0;
    final match = RegExp(r'^bytes=0-([0-9]+)$').firstMatch(range);
    final last = int.tryParse(match?.group(1) ?? '');
    if (last == null || last >= length) {
      throw const FormatException(
          'Drive ha restituito un intervallo non valido');
    }
    return last + 1;
  }

  void _finishUpload(String path, DriveHttpResponse response) {
    if (response.body.isNotEmpty) {
      final id = (jsonDecode(response.bodyText) as Map)['id'] as String?;
      if (id != null) _attachmentIds[path] = id;
    }
    _uploadSessions.remove(path);
  }

  Future<bool> _download(String path, File target) async {
    final id = await _findAttachment(path);
    if (id == null) return false;
    final item = '${DriveSyncGateway._apiRoot}/${Uri.encodeComponent(id)}';
    final metadata = await _send('GET', Uri.parse('$item?fields=size'));
    if (metadata.statusCode == 404) {
      _attachmentIds.remove(path);
      return false;
    }
    _require(metadata);
    final size =
        int.parse((jsonDecode(metadata.bodyText) as Map)['size'] as String);
    _checkSize(size);
    final output = await target.open(mode: FileMode.write);
    try {
      for (var start = 0; start < size; start += _transferBlock) {
        final end = start + _transferBlock < size
            ? start + _transferBlock - 1
            : size - 1;
        final part = await _send('GET', Uri.parse('$item?alt=media'),
            headers: {'Range': 'bytes=$start-$end'});
        _require(part);
        if (part.body.length != end - start + 1 ||
            (part.statusCode == 206
                ? part.headers['content-range'] != 'bytes $start-$end/$size'
                : start != 0 || end != size - 1)) {
          throw const FormatException('Blocco scaricato non valido');
        }
        await output.writeFrom(part.body);
      }
      await output.flush();
      return true;
    } finally {
      await output.close();
    }
  }

  void _checkSize(int size) {
    if (size <= 0 || size > _maximumEncryptedAttachmentSize) {
      throw const FormatException(
          'Dimensione dell’allegato cifrato non valida');
    }
  }
}
