import 'sync_auth.dart';

/// L'accesso finché l'app non ha le sue credenziali Google.
///
/// Un'applicazione distribuita ha bisogno di un **proprio** client OAuth,
/// registrato dal suo autore in Google Cloud: è quello che permette a ogni
/// utente di accedere con il proprio account e di sincronizzare sul proprio
/// Drive, senza che nessuno usi l'account di un altro. Finché quel client non
/// esiste, il pulsante resta spento e lo dice, invece di fallire in modo
/// incomprensibile.
class UnconfiguredSyncAuthService implements SyncAuthService {
  const UnconfiguredSyncAuthService();

  static const String reason =
      'Serve un client OAuth dell\'app (Google Cloud) per accedere con il tuo '
      'account Google. Finché non è configurato, i dati restano su questo '
      'dispositivo.';

  @override
  bool get isSupported => false;

  @override
  bool get isSignedIn => false;

  @override
  SyncAccount? get account => null;

  @override
  Future<SyncAccount> signIn() async => throw StateError(reason);

  @override
  Future<void> signOut() async {}

  @override
  Future<String> accessToken() async => throw StateError(reason);
}
