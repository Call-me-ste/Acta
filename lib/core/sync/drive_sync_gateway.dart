import 'dart:convert';
import 'dart:io';

import 'drive_failure.dart';
import 'drive_http.dart';
import 'encrypted_sync_gateway.dart';
import 'sync_attachment_transport.dart';
import 'sync_auth.dart';
import 'sync_gateway.dart';

part 'drive_attachment_transfer.dart';

/// Il gateway su **Google Drive AppData**, con il token dell'utente.
///
/// Drive non ha percorsi: è un archivio di file identificati da un id. I
/// percorsi relativi del sync (`todo/2026-09.jsonl.gz`) diventano quindi il
/// **nome** del file, con `/` codificato: la cartella AppData resta piatta e non
/// serve creare e ritrovare sottocartelle a ogni scrittura.
///
/// ponytail: l'indice dei nomi si richiede a ogni operazione, così una scrittura
/// costa una richiesta in più. Un push fa poche scritture; se un giorno pesasse,
/// la strada è tenere l'indice per la durata di un push, non cambiare il formato.
class DriveSyncGateway implements SyncGateway, SyncAttachmentTransport {
  DriveSyncGateway({required this.auth, DriveHttpClient? http})
      : _http = http ?? IoDriveHttpClient();

  static const String scope = 'https://www.googleapis.com/auth/drive.appdata';

  static const String _apiRoot = 'https://www.googleapis.com/drive/v3/files';
  static const String _uploadRoot =
      'https://www.googleapis.com/upload/drive/v3/files';
  static const String _separator = '__';
  static const String _boundary = 'planner-sync-boundary';

  final SyncAuthService auth;
  final DriveHttpClient _http;
  final _uploadSessions = <String, Uri>{};
  final _attachmentIds = <String, String>{};
  final _changeIds = <String, String>{};

  @override
  Future<bool> hasAttachment(String path) async =>
      await _findAttachment(path) != null;

  @override
  Future<void> uploadAttachment(String path, File source) =>
      _upload(path, source);

  @override
  Future<bool> downloadAttachment(String path, File target) =>
      _download(path, target);

  @override
  Future<List<String>> list(String prefix) async {
    final index = await _index();
    if (prefix == EncryptedSyncGateway.changesPrefix) {
      _changeIds
        ..clear()
        ..addEntries(
            index.entries.where((entry) => entry.key.startsWith(prefix)));
    }
    final paths = index.keys.where((path) => path.startsWith(prefix)).toList()
      ..sort();
    return paths;
  }

  @override
  Future<List<int>?> read(String path) async {
    final id = _changeIds[path] ?? (await _index())[path];
    if (id == null) return null;

    final response = await _send('GET', Uri.parse('$_apiRoot/$id?alt=media'));
    if (response.statusCode == 404) {
      _changeIds.remove(path);
      return null;
    }
    _require(response);
    return response.body;
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    final id = (await _index())[path];

    if (id == null) {
      final response = await _send(
        'POST',
        Uri.parse('$_uploadRoot?uploadType=multipart&fields=id'),
        body: _multipart(path, bytes),
        contentType: 'multipart/related; boundary=$_boundary',
      );
      _require(response);
      if (path.startsWith(EncryptedSyncGateway.changesPrefix)) {
        final created = jsonDecode(response.bodyText) as Map<String, Object?>;
        if (created['id'] case final String id) _changeIds[path] = id;
      }
      return;
    }

    final response = await _send(
      'PATCH',
      Uri.parse('$_uploadRoot/$id?uploadType=media'),
      body: bytes,
      contentType: 'application/octet-stream',
    );
    _require(response);
    if (path.startsWith(EncryptedSyncGateway.changesPrefix)) {
      _changeIds[path] = id;
    }
  }

  @override
  Future<void> delete(String path) async {
    final id = (await _index())[path];
    if (id == null) return;

    final response = await _send('DELETE', Uri.parse('$_apiRoot/$id'));
    if (response.statusCode == 404) return;
    _require(response);
  }

  /// Corpo multipart: metadati (nome + cartella AppData) e contenuto.
  List<int> _multipart(String path, List<int> bytes) {
    final metadata = jsonEncode({
      'name': _encode(path),
      'parents': ['appDataFolder'],
    });

    final head = '--$_boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$_boundary\r\n'
        'Content-Type: application/octet-stream\r\n\r\n';
    const tail = '\r\n--$_boundary--\r\n';

    return [...utf8.encode(head), ...bytes, ...utf8.encode(tail)];
  }

  /// Nome file → percorso. Le barre non possono stare in un nome di Drive (e
  /// comunque la cartella è piatta), quindi si codificano.
  static String _encode(String path) => path.replaceAll('/', _separator);
  static String _decode(String name) {
    // The URL-safe hash can itself contain "__". Only decode the known
    // separators of encrypted object names already stored with this format.
    for (final prefix in const [
      'encrypted-v1/data/',
      'encrypted-v1/blob/',
      EncryptedSyncGateway.changesPrefix,
    ]) {
      final encoded = _encode(prefix);
      if (name.startsWith(encoded)) {
        return prefix + name.substring(encoded.length);
      }
    }
    return name.replaceAll(_separator, '/');
  }

  Future<Map<String, String>> _index() async {
    final index = <String, String>{};
    final seenTokens = <String>{};
    String? pageToken;

    do {
      final url = Uri.parse(_apiRoot).replace(queryParameters: {
        'spaces': 'appDataFolder',
        'pageSize': '1000',
        'orderBy': 'modifiedTime',
        'fields': 'nextPageToken,files(id,name)',
        if (pageToken != null) 'pageToken': pageToken,
      });
      final response = await _send('GET', url);
      _require(response);

      final json =
          (jsonDecode(response.bodyText) as Map).cast<String, Object?>();
      for (final file in (json['files'] as List? ?? const [])) {
        final entry = (file as Map).cast<String, Object?>();
        index[_decode(entry['name'] as String)] = entry['id'] as String;
      }
      pageToken = json['nextPageToken'] as String?;
      if (pageToken != null && !seenTokens.add(pageToken)) {
        throw const DriveFailure(DriveFailureKind.request);
      }
    } while (pageToken != null);

    return index;
  }

  Future<DriveHttpResponse> _send(
    String method,
    Uri url, {
    List<int>? body,
    String? contentType,
    Map<String, String> headers = const {},
  }) async {
    return _http.send(
      method: method,
      url: url,
      headers: {
        'Authorization': 'Bearer ${await auth.accessToken()}',
        if (contentType != null) 'Content-Type': contentType,
        ...headers,
      },
      body: body,
    );
  }

  void _require(DriveHttpResponse response) {
    if (!response.isSuccess) throw DriveFailure.fromResponse(response);
  }
}
