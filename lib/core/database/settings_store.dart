import 'package:sqlite3/sqlite3.dart';

/// Le preferenze di questo device: chiave/valore in `app_settings`.
///
/// Sta fuori da `DatabaseService` per lo stesso motivo degli altri store: quel
/// file ha un budget di 300 righe e qui c'è solo SQL di pertinenza.
///
/// Tutto è una stringa: chi legge sa se quella preferenza è un intero, un bool
/// o una data, e la converte con un default esplicito. Un JSON qui dentro
/// sarebbe comodo e sbagliato: le preferenze si leggono una per una.
class SettingsStore {
  SettingsStore(this._db);

  final Database _db;

  String? get(String key) {
    final rows =
        _db.select('SELECT value FROM app_settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Map<String, String> all() {
    final result = <String, String>{};
    for (final row in _db.select('SELECT key, value FROM app_settings')) {
      result[row['key'] as String] = row['value'] as String;
    }
    return result;
  }

  void set(String key, String value) {
    _db.execute(
      'INSERT INTO app_settings (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }

  void remove(String key) {
    _db.execute('DELETE FROM app_settings WHERE key = ?', [key]);
  }
}
