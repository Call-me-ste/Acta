/// La versione dell'app e dello **schema** del database, in un posto solo.
///
/// Perche' esistono come costanti e non si leggono da `pubspec.yaml` a runtime:
/// leggerle vorrebbe dire una dipendenza in piu' (`package_info_plus`) per due
/// stringhe. Il rischio di questo modo — la costante e `pubspec.yaml` che si
/// allontanano — lo chiude un test: `test/core/app_version_test.dart` legge il
/// `pubspec.yaml` vero e pretende che i due numeri combacino.
///
/// Regola di consegna (una build consegnata = un numero in piu'):
///   `pubspec.yaml` → `version: 1.1.0+N`, con `N` che sale a ogni consegna.
class AppVersion {
  const AppVersion._();

  /// La chiave in `app_settings` con la versione che ha aperto il database
  /// l'ultima volta. Non e' una preferenza dell'utente: serve a riconoscere un
  /// aggiornamento **prima** di toccare lo schema (vedi `DatabaseService.init`).
  static const String settingsKey = 'appVersion';

  /// Il nome della versione, quello che si legge in Impostazioni.
  static const String name = '1.3.0';

  /// Il numero di build Android (`versionCode`): sale **a ogni** consegna.
  static const int build = 55;

  /// `1.1.0+2`, come sta scritto in `pubspec.yaml`.
  static const String full = '$name+$build';
}
