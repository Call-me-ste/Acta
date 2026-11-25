import 'package:sqlite3/sqlite3.dart';

import '../app_version.dart';

/// La versione dell'app che ha aperto il database l'ultima volta.
///
/// Sta fuori da `database_service.dart` per il tetto delle 300 righe: qui c'e'
/// solo la lettura di una chiave che esiste in `app_settings`, e che va letta
/// **prima** di applicare lo schema. Un database molto vecchio puo' non avere
/// ancora la tabella: in quel caso non c'e' nessuna versione da confrontare.
String? readAppVersion(Database db) {
  final tabella = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name = 'app_settings'",
  );
  if (tabella.isEmpty) return null;
  final righe = db.select(
    'SELECT value FROM app_settings WHERE key = ?',
    [AppVersion.settingsKey],
  );
  return righe.isEmpty ? null : righe.first['value'] as String;
}
