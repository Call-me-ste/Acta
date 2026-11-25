import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/app_version.dart';
import 'github_update.dart';

enum UpdateCheckStatus {
  idle,
  checking,
  available,
  noCompatibleUpdate,
  noPublicRelease,
  unsupported,
  failed,
}

class UpdateController extends ChangeNotifier {
  UpdateController({
    Future<GitHubUpdate?> Function(int)? fetch,
    Future<bool> Function()? canCheck,
  })  : _fetch = fetch ?? fetchGitHubUpdate,
        _canCheck = canCheck ?? _platformCanCheck;

  static const channel = MethodChannel('planner/updates');
  final Future<GitHubUpdate?> Function(int) _fetch;
  final Future<bool> Function() _canCheck;
  DateTime? _lastCheck;
  GitHubUpdate? _available;
  int? _dismissed;
  bool? _eligible;
  bool _disposed = false;
  UpdateCheckStatus _status = UpdateCheckStatus.idle;

  UpdateCheckStatus get status => _status;
  GitHubUpdate? get available => _available;
  GitHubUpdate? get visible =>
      _available?.build == _dismissed ? null : _available;

  static Future<bool> _platformCanCheck() async =>
      await channel.invokeMethod<bool>('canCheck') ?? false;

  Future<void> check({bool manual = false}) async {
    final now = DateTime.now();
    final last = _lastCheck;
    if (_disposed ||
        _eligible == false ||
        _status == UpdateCheckStatus.checking ||
        (!manual &&
            last != null &&
            now.difference(last) < const Duration(minutes: 5))) {
      return;
    }
    _lastCheck = now;
    _setStatus(UpdateCheckStatus.checking);
    try {
      _eligible ??= await _canCheck();
      if (_disposed) return;
      if (_eligible == false) {
        _setStatus(UpdateCheckStatus.unsupported);
        return;
      }
      final update = await _fetch(AppVersion.build);
      if (_disposed) return;
      _available = update;
      _setStatus(update == null
          ? UpdateCheckStatus.noCompatibleUpdate
          : UpdateCheckStatus.available);
    } on GitHubReleaseNotFound {
      _available = null;
      _setStatus(UpdateCheckStatus.noPublicRelease);
    } on MissingPluginException {
      _eligible = false;
      _setStatus(UpdateCheckStatus.unsupported);
    } catch (_) {
      _available = null;
      _setStatus(UpdateCheckStatus.failed);
    }
  }

  void _setStatus(UpdateCheckStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  void dismiss() {
    _dismissed = _available?.build;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
