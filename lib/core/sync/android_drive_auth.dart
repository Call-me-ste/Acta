import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'drive_http.dart';
import 'sync_auth.dart';

class AndroidDriveAuthService implements SyncAuthService {
  AndroidDriveAuthService({
    MethodChannel channel = const MethodChannel('planner/drive_auth'),
    DriveHttpClient? http,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  })  : _channel = channel,
        _storage = storage,
        _http = http ?? IoDriveHttpClient();

  static const _slot = 'planner.drive.account.v1';
  static final _about = Uri.https(
    'www.googleapis.com',
    '/drive/v3/about',
    {'fields': 'user(emailAddress,displayName)'},
  );
  final MethodChannel _channel;
  final DriveHttpClient _http;
  final FlutterSecureStorage _storage;
  SyncAccount? _account;
  Future<String>? _pendingToken;

  @override
  bool get isSupported => true;
  @override
  bool get isSignedIn => _account != null;
  @override
  SyncAccount? get account => _account;

  Future<bool> restore() async {
    final email = await _storage.read(key: _slot);
    if (email == null) return false;
    _account = SyncAccount(email: email);
    return true;
  }

  @override
  Future<SyncAccount> signIn() async {
    final token = await _authorize(interactive: true, email: _account?.email);
    final response = await _http.send(
      method: 'GET',
      url: _about,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (!response.isSuccess) {
      throw StateError(
          'Impossibile leggere l’account Drive (HTTP ${response.statusCode}).');
    }
    final user = (jsonDecode(response.bodyText) as Map)['user'] as Map?;
    final email = user?['emailAddress'] as String?;
    if (email == null || email.isEmpty) {
      throw StateError(
          'Google Drive non ha restituito l’indirizzo dell’account.');
    }
    if (_account != null &&
        _account!.email.toLowerCase() != email.toLowerCase()) {
      throw StateError('Scollega l’account corrente prima di cambiarlo.');
    }
    final account =
        SyncAccount(email: email, displayName: user?['displayName'] as String?);
    await _storage.write(key: _slot, value: email);
    return _account = account;
  }

  @override
  Future<String> accessToken() async {
    final email = _account?.email;
    if (email == null) throw StateError('Collega prima Google Drive.');
    final pending =
        _pendingToken ??= _authorize(interactive: false, email: email);
    try {
      return await pending;
    } finally {
      if (identical(_pendingToken, pending)) _pendingToken = null;
    }
  }

  Future<String> _authorize({required bool interactive, String? email}) async {
    final token = await _channel.invokeMethod<String>(
      'authorize',
      {'interactive': interactive, if (email != null) 'email': email},
    );
    if (token == null || token.isEmpty) {
      throw StateError('Autorizzazione Google Drive non disponibile.');
    }
    return token;
  }

  @override
  Future<void> signOut() async {
    final email = _account?.email;
    if (email == null) return;
    await _channel.invokeMethod<void>('revoke', {'email': email});
    await _storage.delete(key: _slot);
    _account = null;
  }
}
