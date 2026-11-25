import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/storage_failure.dart';
import '../../core/sync/drive_failure.dart';
import '../../core/sync/encrypted_sync_gateway.dart';
import '../../core/sync/sync_auth.dart';
import '../../core/sync/sync_gateway.dart';
import '../../core/sync/sync_service.dart';

enum SyncProblem {
  driveFull(
      'Google Drive è pieno. Le modifiche salvate restano sul dispositivo.'),
  deviceFull(deviceStorageFullMessage),
  connection('Google Drive non è raggiungibile. Riproveremo quando possibile.'),
  temporary(
      'Google Drive è temporaneamente indisponibile. Riproveremo tra poco.'),
  signIn('Ricollega Google Drive per continuare.'),
  permission(
      'Acta non ha accesso a Google Drive. Controlla i permessi dell’account.'),
  archiveMissing(
      'L’archivio Drive non è più disponibile. Le copie locali restano accessibili.'),
  archiveIncompatible(
      'L’archivio Drive è di un formato precedente. Puoi ancora esportare i dati locali.'),
  archiveDamaged(
      'Il recupero da Drive è incompleto. Parte dell’archivio non è leggibile. Verifica le altre copie disponibili.'),
  recovery('Serve la chiave di Acta per aprire l’archivio Drive.'),
  wrongAccount('Questo archivio è associato a un altro account Google.'),
  incomplete('Sincronizzazione incompleta. Controlla i tuoi dati e riprova.');

  const SyncProblem(this.message);
  final String message;
}

/// Lo stato del sync per le impostazioni: chi è collegato, cosa è in attesa,
/// com'è andata l'ultima volta.
///
/// Il pulsante "Google Drive" passa da qui: collega l'account **dell'utente**,
/// installa il gateway e fa partire il primo giro. Nessuna scorciatoia con
/// l'account di chi ha sviluppato l'app: ogni utente usa il proprio Drive.
class SyncController extends ChangeNotifier {
  SyncController({
    required this.auth,
    required this.sync,
    required this.createGateway,
    this.configureGateway,
    this.createFreshArchive,
    this.restoreAccount,
    this.onPulled,
    this.canPoll,
  });

  final SyncAuthService auth;
  final SyncService sync;
  final SyncGateway Function() createGateway;
  final Future<SyncGateway> Function(SyncGateway)? configureGateway;
  final Future<SyncGateway> Function(SyncGateway, VoidCallback)?
      createFreshArchive;
  final Future<bool> Function()? restoreAccount;
  final VoidCallback? onPulled;
  final bool Function()? canPoll;
  Timer? _polling;

  bool _busy = false;
  bool _paused = false;
  SyncProblem? _problem;
  DateTime? _nextRetry;
  int _retryMinutes = 1;
  bool _needsRecovery = false;
  bool _wrongAccount = false;

  bool get isBusy => _busy;
  bool get isSupported => auth.isSupported;
  bool get isSignedIn => auth.isSignedIn;
  bool get needsRecovery => _needsRecovery;
  bool get wrongAccount => _wrongAccount;
  bool get canRecoverFromDrive => sync.activeGateway is EncryptedSyncGateway;
  SyncAccount? get account => auth.account;
  int get pendingCount => sync.pendingCount;
  DateTime? get lastSyncTime => sync.lastSyncTime;
  int? get remoteShardCount => sync.remoteShardCount;
  SyncProblem? get problem => _problem;
  String? get lastError => _problem?.message;

  /// Collega l'account e fa il primo giro completo.
  Future<void> connect() async {
    await _run(() async {
      // Prima l'accesso, poi il gateway: finché le credenziali dell'app non
      // esistono, l'errore che l'utente legge deve essere quello dell'accesso,
      // non un messaggio sul gateway.
      await auth.signIn();
      await _configure();
      await _synchronize();
    });
  }

  Future<void> signOut() async {
    await _run(() async {
      await auth.signOut();
      _polling?.cancel();
      _polling = null;
      sync.useGateway(null);
    });
  }

  Future<void> restoreConnection() async {
    final restore = restoreAccount;
    if (restore == null) return;
    await _run(() async {
      if (await restore()) {
        _startPolling();
        await _configure();
        await _synchronize();
      }
    });
  }

  Future<void> syncNow() => _run(() async {
        try {
          if (!sync.isConfigured && configureGateway != null) {
            await _configure();
          }
          await _synchronize();
        } on PlatformException catch (error) {
          if (error.code != 'consent_required') rethrow;
          await auth.signIn();
          await _configure();
          await _synchronize();
        }
      });

  Future<void> _configure() async {
    final email = account?.email.toLowerCase();
    sync.checkArchiveAccount(email);
    final gateway = createGateway();
    sync.useGateway(await configureGateway?.call(gateway) ?? gateway,
        accountKey: email);
    _startPolling();
  }

  Future<void> whileRestoring(Future<void> Function() restore) async {
    if (_paused || _busy) {
      throw StateError('Attendi la fine dell’operazione in corso e riprova.');
    }
    _paused = true;
    try {
      await restore();
    } finally {
      _paused = false;
    }
  }

  Future<void> recoverFromDrive() => _run(
        () => _synchronize(recover: true),
      );

  Future<void> rebuildArchive() => _run(() async {
        final email = account?.email.toLowerCase();
        final create = createFreshArchive;
        if (email == null || create == null) return;
        sync.checkArchiveAccount(email);
        final gateway = await create(
            createGateway(), () => sync.enqueueForNewArchive(email));
        sync.useGateway(gateway, accountKey: email);
        _startPolling();
        await _synchronize();
      });

  void _startPolling() {
    final inForeground = canPoll;
    if (inForeground != null) {
      _polling ??= Timer.periodic(const Duration(minutes: 2), (_) {
        final retry = _nextRetry;
        if (inForeground() &&
            !_requiresAction &&
            (retry == null || !DateTime.now().isBefore(retry))) {
          unawaited(_run(() async {
            if (!sync.isConfigured) await _configure();
            await _synchronize();
          }));
        }
      });
    }
  }

  bool get _requiresAction => switch (_problem) {
        SyncProblem.driveFull ||
        SyncProblem.deviceFull ||
        SyncProblem.signIn ||
        SyncProblem.permission ||
        SyncProblem.archiveMissing ||
        SyncProblem.archiveIncompatible ||
        SyncProblem.archiveDamaged ||
        SyncProblem.wrongAccount ||
        SyncProblem.recovery =>
          true,
        _ => false,
      };

  Future<void> _synchronize({bool recover = false}) async {
    final before = sync.appliedRevision;
    try {
      await (recover ? sync.recoverRemote() : sync.fullSync());
      final failure = sync.lastFailure;
      if (failure != null) _problem = _describe(failure);
    } finally {
      if (sync.appliedRevision != before) onPulled?.call();
    }
  }

  @override
  void dispose() {
    _polling?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _paused) return;
    _busy = true;
    _problem = null;
    _needsRecovery = false;
    _wrongAccount = false;
    notifyListeners();

    try {
      await action();
    } on PlatformException catch (error) {
      if (error.code != 'cancelled') _problem = _describe(error);
    } catch (error) {
      _problem = _describe(error);
    } finally {
      _needsRecovery = _problem == SyncProblem.recovery;
      _wrongAccount = _problem == SyncProblem.wrongAccount;
      if (_problem == SyncProblem.connection ||
          _problem == SyncProblem.temporary) {
        _retryMinutes = (_retryMinutes * 2).clamp(2, 30);
        _nextRetry = DateTime.now().add(Duration(minutes: _retryMinutes));
      } else {
        _retryMinutes = 1;
        _nextRetry = null;
      }
      _busy = false;
      notifyListeners();
    }
  }

  static SyncProblem _describe(Object error) => switch (error) {
        _ when isDeviceStorageFull(error) => SyncProblem.deviceFull,
        DriveFailure(kind: DriveFailureKind.storageFull) =>
          SyncProblem.driveFull,
        DriveFailure(kind: DriveFailureKind.signIn) => SyncProblem.signIn,
        DriveFailure(kind: DriveFailureKind.permission) =>
          SyncProblem.permission,
        DriveFailure(kind: DriveFailureKind.temporary) => SyncProblem.temporary,
        SocketException() || TimeoutException() => SyncProblem.connection,
        ArchiveRecoveryRequired() => SyncProblem.recovery,
        ArchiveAccountMismatch() => SyncProblem.wrongAccount,
        DriveArchiveMissing() => SyncProblem.archiveMissing,
        DriveArchiveIncompatible() => SyncProblem.archiveIncompatible,
        DriveArchiveDamaged() => SyncProblem.archiveDamaged,
        PlatformException(code: 'consent_required') => SyncProblem.signIn,
        _ => SyncProblem.incomplete,
      };
}
