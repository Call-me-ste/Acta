/// L'account con cui si sincronizza.
class SyncAccount {
  const SyncAccount({required this.email, this.displayName});

  final String email;
  final String? displayName;

  @override
  String toString() => email;
}

/// Chi ottiene il permesso di scrivere sul Drive **dell'utente**.
///
/// Il modello è quello che permette di distribuire l'app: **un client OAuth
/// dell'applicazione** registrato in Google Cloud, e **un token per utente**.
/// Nessuno usa l'account di chi ha scritto l'app: ogni utente vede e sincronizza
/// solo i propri dati, nella propria cartella AppData.
///
/// L'implementazione cambia per piattaforma — su Android/iOS c'è
/// `google_sign_in`, sul desktop serve il flusso con reindirizzamento su
/// localhost — ma il resto del sync non lo sa e non deve saperlo.
abstract interface class SyncAuthService {
  bool get isSignedIn;
  SyncAccount? get account;

  /// `true` quando l'implementazione può funzionare su questa piattaforma.
  /// Le impostazioni usano questo per non offrire un pulsante che fallirebbe.
  bool get isSupported;

  Future<SyncAccount> signIn();
  Future<void> signOut();

  /// Un token di accesso valido ora, rinnovato se serve.
  Future<String> accessToken();
}
