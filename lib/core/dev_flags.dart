import 'package:flutter/services.dart';

/// **Che build è questa**: quella di test o quella ufficiale.
///
/// Il default è la build **ufficiale**: chi lancia `flutter build apk` senza
/// niente ottiene l'app per l'uso vero, e i comandi di sviluppo restano fuori
/// per distrazione. La build di test si chiede apposta:
///
/// ```bash
/// flutter build apk --release --flavor qa --target-platform android-arm64
/// ```
///
/// Una **costante** compilata, non una preferenza: sta nel codice, non in
/// `app_settings`, così il ramo di sviluppo non esiste proprio nel binario
/// ufficiale (le stringhe dei dati di prova non ci sono: si vede con `strings`).
const bool devTools =
    appFlavor == 'qa' || (appFlavor == null && bool.fromEnvironment('dev'));

/// Il nome **di questa build**, quello che finisce in `app_settings`: serve a
/// distinguere i dati scritti dalla build di test da quelli della ufficiale,
/// per fare la copia prima di cambiare (vedi `BackupController`).
const String buildKind = devTools ? 'test' : 'ufficiale';

/// La stessa cosa scritta per l'utente, e anche questa è una costante: nella
/// build ufficiale è la stringa vuota, quindi non resta nel binario.
const String devMarker = devTools ? ' · build di test' : '';
