import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/sync/drive_http.dart';
import 'package:planner/core/sync/drive_failure.dart';
import 'package:planner/core/sync/drive_sync_gateway.dart';
import 'package:planner/core/sync/sync_auth.dart';

/// Le richieste che il gateway ha davvero fatto, e le risposte preparate.
class RecordingDriveHttp implements DriveHttpClient {
  final List<
      ({
        String method,
        Uri url,
        Map<String, String> headers,
        List<int>? body
      })> calls = [];
  final List<DriveHttpResponse> responses = [];

  void respond(DriveHttpResponse response) => responses.add(response);

  @override
  Future<DriveHttpResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<int>? body,
  }) async {
    calls.add((method: method, url: url, headers: headers, body: body));
    if (responses.isEmpty) {
      throw StateError(
          'Nessuna risposta preparata per ${method.toString()} $url');
    }
    return responses.removeAt(0);
  }
}

class FakeAuth implements SyncAuthService {
  @override
  bool get isSupported => true;
  @override
  bool get isSignedIn => true;
  @override
  SyncAccount? get account => const SyncAccount(email: 'utente@example.com');
  @override
  Future<SyncAccount> signIn() async => account!;
  @override
  Future<void> signOut() async {}
  @override
  Future<String> accessToken() async => 'token-di-prova';
}

DriveHttpResponse ok(String body) => DriveHttpResponse(
      statusCode: 200,
      body: utf8.encode(body),
    );

void main() {
  late RecordingDriveHttp http;
  late DriveSyncGateway gateway;

  setUp(() {
    http = RecordingDriveHttp();
    gateway = DriveSyncGateway(auth: FakeAuth(), http: http);
  });

  test('riprende un upload PDF dal blocco confermato da Drive', () async {
    final temp = await Directory.systemTemp.createTemp('planner-drive-test-');
    addTearDown(() => temp.delete(recursive: true));
    const block = 2 * 1024 * 1024;
    final file = await File.fromUri(temp.uri.resolve('sealed'))
        .writeAsBytes(Uint8List(block + 16));
    http.respond(const DriveHttpResponse(statusCode: 200, body: [], headers: {
      'location':
          'https://www.googleapis.com/upload/drive/v3/files?upload_id=test',
    }));
    http.respond(const DriveHttpResponse(
        statusCode: 308, body: [], headers: {'range': 'bytes=0-2097151'}));
    http.respond(const DriveHttpResponse(statusCode: 503, body: []));
    await expectLater(
        gateway.uploadAttachment('blob/path', file),
        throwsA(isA<DriveFailure>()
            .having((e) => e.kind, 'tipo', DriveFailureKind.temporary)));
    http.respond(const DriveHttpResponse(
        statusCode: 308, body: [], headers: {'range': 'bytes=0-2097151'}));
    http.respond(ok('{"id":"sealed-id"}'));
    await gateway.uploadAttachment('blob/path', file);
    expect(http.calls.where((call) => call.method == 'POST'), hasLength(1));
    expect(http.calls[3].headers['Content-Range'], 'bytes */${block + 16}');
    expect(http.calls.last.headers['Content-Range'],
        'bytes $block-${block + 15}/${block + 16}');
    expect(http.calls.last.body, hasLength(16));
    expect(await gateway.hasAttachment('blob/path'), isTrue);
  });

  test('una sessione scaduta riparte da zero con una sola nuova sessione',
      () async {
    final temp = await Directory.systemTemp.createTemp('planner-drive-expiry-');
    addTearDown(() => temp.delete(recursive: true));
    final file =
        await File.fromUri(temp.uri.resolve('sealed')).writeAsBytes([1, 2, 3]);
    DriveHttpResponse session(String id) =>
        DriveHttpResponse(statusCode: 200, body: const [], headers: {
          'location':
              'https://www.googleapis.com/upload/drive/v3/files?upload_id=$id',
        });
    http.respond(session('old'));
    http.respond(const DriveHttpResponse(statusCode: 503, body: []));
    await expectLater(gateway.uploadAttachment('blob/path', file),
        throwsA(isA<DriveFailure>()));
    http.respond(const DriveHttpResponse(statusCode: 404, body: []));
    http.respond(session('new'));
    http.respond(ok('{"id":"sealed-id"}'));

    await gateway.uploadAttachment('blob/path', file);
    expect(http.calls.where((call) => call.method == 'POST'), hasLength(2));
    expect(http.calls.last.url.queryParameters['upload_id'], 'new');
    expect(http.calls.last.headers['Content-Range'], 'bytes 0-2/3');
  });

  group('percorsi', () {
    test('l\'elenco traduce i nomi di Drive in percorsi', () async {
      const listing = '{"files":['
          '{"id":"id-todo","name":"todo__2026-09.jsonl.gz"},'
          '{"id":"id-note","name":"note__2026-09.jsonl.gz"}]}';
      // Ogni elenco è una richiesta: il gateway non tiene un indice in cache.
      http.respond(ok(listing));
      http.respond(ok(listing));

      expect(await gateway.list('todo/'), ['todo/2026-09.jsonl.gz']);
      expect(await gateway.list(''), hasLength(2));

      // La prima chiamata chiede la cartella AppData e il token dell'utente.
      expect(http.calls.first.url.query, contains('spaces=appDataFolder'));
      expect(
          http.calls.first.headers['Authorization'], 'Bearer token-di-prova');
    });

    test('legge il contenuto per id, chiedendo i byte', () async {
      http.respond(ok('{"files":[{"id":"id-1","name":"manifest.json"}]}'));
      http.respond(const DriveHttpResponse(statusCode: 200, body: [1, 2, 3]));

      expect(await gateway.read('manifest.json'), [1, 2, 3]);
      expect(http.calls.last.url.path, endsWith('/id-1'));
      expect(http.calls.last.url.query, 'alt=media');
    });

    test('conserva i doppi underscore negli identificatori cifrati', () async {
      const listing = '{"files":['
          '{"id":"older-id","name":"encrypted-v1__data__ab__cd"},'
          '{"id":"recent-id","name":"encrypted-v1__data__ab__cd"}]}';
      const path = 'encrypted-v1/data/ab__cd';
      http.respond(ok(listing));
      http.respond(ok(listing));
      http.respond(const DriveHttpResponse(statusCode: 200, body: [4, 2]));

      expect(await gateway.list('encrypted-v1/data/'), [path]);
      expect(await gateway.read(path), [4, 2]);
      expect(http.calls[1].url.queryParameters['orderBy'], 'modifiedTime');
      expect(http.calls.last.url.path, endsWith('/recent-id'));
    });

    test('un percorso che non esiste è assenza, non errore', () async {
      http.respond(ok('{"files":[]}'));

      expect(await gateway.read('todo/niente.jsonl.gz'), isNull);
      // Nessuna richiesta oltre all'elenco: non c'è niente da leggere.
      expect(http.calls, hasLength(1));
    });
  });

  group('scrittura', () {
    test('un file nuovo nasce nella cartella AppData, col nome codificato',
        () async {
      http.respond(ok('{"files":[]}'));
      http.respond(ok('{"id":"id-nuovo"}'));

      await gateway.write('todo/2026-09.jsonl.gz', [9, 8, 7]);

      final create = http.calls.last;
      expect(create.method, 'POST');
      expect(create.url.query, contains('uploadType=multipart'));

      final body = utf8.decode(create.body!, allowMalformed: true);
      expect(body, contains('"name":"todo__2026-09.jsonl.gz"'));
      expect(body, contains('"parents":["appDataFolder"]'));
      // I byte veri stanno fra i metadati e la chiusura del multipart.
      const closing = '\r\n--planner-sync-boundary--\r\n';
      final payloadStart = create.body!.length - closing.length - 3;
      expect(create.body!.sublist(payloadStart, payloadStart + 3), [9, 8, 7]);
    });

    test('un file che esiste viene aggiornato, non duplicato', () async {
      http.respond(
          ok('{"files":[{"id":"id-1","name":"todo__2026-09.jsonl.gz"}]}'));
      http.respond(ok('{}'));

      await gateway.write('todo/2026-09.jsonl.gz', [4, 5]);

      final update = http.calls.last;
      expect(update.method, 'PATCH');
      expect(update.url.path, endsWith('/id-1'));
      expect(update.url.query, 'uploadType=media');
      expect(update.body, [4, 5]);
    });

    test('cancellare un file che non c\'è non chiama Drive', () async {
      http.respond(ok('{"files":[]}'));

      await gateway.delete('todo/2026-09.jsonl.gz');

      expect(http.calls, hasLength(1));
    });
  });

  group('errori', () {
    for (final (status, reason, kind) in [
      (401, '', DriveFailureKind.signIn),
      (403, 'storageQuotaExceeded', DriveFailureKind.storageFull),
      (403, 'userRateLimitExceeded', DriveFailureKind.temporary),
      (403, 'rateLimitExceeded', DriveFailureKind.temporary),
      (403, 'insufficientFilePermissions', DriveFailureKind.permission),
      (403, '', DriveFailureKind.permission),
      (429, '', DriveFailureKind.temporary),
      (500, '', DriveFailureKind.temporary),
      (503, '', DriveFailureKind.temporary),
      (400, '', DriveFailureKind.request),
    ]) {
      test('classifica $status $reason senza mostrare il corpo di Drive',
          () async {
        http.respond(DriveHttpResponse(
            statusCode: status,
            body: utf8.encode(
              reason.isEmpty
                  ? '<risposta grezza>'
                  : jsonEncode({
                      'error': {
                        'errors': [
                          {'reason': reason}
                        ],
                        'message': 'dettagli riservati'
                      },
                    }),
            )));
        await expectLater(
            gateway.list(''),
            throwsA(isA<DriveFailure>()
                .having((failure) => failure.kind, 'motivo', kind)
                .having((failure) => failure.toString(), 'messaggio',
                    isNot(contains('dettagli riservati')))));
      });
    }
  });
}
