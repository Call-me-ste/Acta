import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// La risposta di una chiamata HTTP, ridotta a quello che serve al gateway.
class DriveHttpResponse {
  const DriveHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final List<int> body;
  final Map<String, String> headers;

  String get bodyText => utf8.decode(body, allowMalformed: true);
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Il minimo per parlare con Drive, e niente di più.
///
/// È un'interfaccia per un motivo pratico: i test del gateway girano su una
/// implementazione finta, quindi non aprono socket e non serve un account. La
/// logica sotto test è **quella vera** — costruzione delle richieste, gestione
/// degli errori, mappatura percorsi/identificatori.
abstract interface class DriveHttpClient {
  Future<DriveHttpResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<int>? body,
  });
}

/// L'implementazione reale, con `dart:io`: nessuna dipendenza aggiuntiva.
class IoDriveHttpClient implements DriveHttpClient {
  IoDriveHttpClient({HttpClient? client}) : _client = client ?? HttpClient() {
    _client.connectionTimeout = _timeout;
  }

  final HttpClient _client;
  static const _timeout = Duration(seconds: 30);

  @override
  Future<DriveHttpResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<int>? body,
  }) async {
    final request = await _client.openUrl(method, url).timeout(_timeout);
    request.followRedirects = false;
    headers.forEach(request.headers.set);

    if (body != null) {
      request.headers.contentLength = body.length;
      request.add(body);
    }

    final response = await request.close().timeout(_timeout, onTimeout: () {
      final error = TimeoutException('Drive non ha risposto', _timeout);
      request.abort(error);
      throw error;
    });
    final bytes = <int>[];
    await for (final chunk in response.timeout(_timeout)) {
      if (bytes.length + chunk.length > 16 * 1024 * 1024) {
        throw const FormatException('Risposta di Drive troppo grande');
      }
      bytes.addAll(chunk);
    }

    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name] = values.join(',');
    });

    return DriveHttpResponse(
      statusCode: response.statusCode,
      body: bytes,
      headers: responseHeaders,
    );
  }
}
