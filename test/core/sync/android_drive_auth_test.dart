import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/sync/android_drive_auth.dart';

import 'drive_sync_gateway_test.dart' show RecordingDriveHttp, ok;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('planner/drive_auth');

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  tearDown(() =>
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  test('verifica l’account con Drive e rinnova il token per lo stesso account',
      () async {
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      return call.method == 'authorize' ? 'token-di-prova' : null;
    });
    final http = RecordingDriveHttp()
      ..respond(ok(
          '{"user":{"emailAddress":"test@example.com","displayName":"Test"}}'));
    final auth = AndroidDriveAuthService(channel: channel, http: http);
    expect((await auth.signIn()).email, 'test@example.com');
    expect(calls.first.arguments, {'interactive': true});
    expect(http.calls.single.url.path, '/drive/v3/about');

    final resumed = AndroidDriveAuthService(channel: channel, http: http);
    expect(await resumed.restore(), isTrue);
    expect(await resumed.accessToken(), 'token-di-prova');
    expect(calls.last.arguments,
        {'interactive': false, 'email': 'test@example.com'});
    await resumed.signOut();
    expect(calls.last.method, 'revoke');
    expect(
        await AndroidDriveAuthService(channel: channel, http: http).restore(),
        isFalse);
  });
}
