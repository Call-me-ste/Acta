import 'package:sqlite3/sqlite3.dart';

/// Le palette: la libreria condivisa fra i device.
///
/// I preset e le palette personalizzate vivono nella stessa tabella, distinti da
/// `is_preset`: il sync non deve sapere cosa sia un preset, deve solo copiare
/// righe come per le altre famiglie di entità.
class PaletteStore {
  PaletteStore(this._db);

  final Database _db;

  List<Row> all() {
    return _db.select('SELECT * FROM palettes ORDER BY is_preset DESC, name');
  }

  /// Scrittura esplicita, colonna per colonna: nessun SQL costruito da chiavi
  /// esterne (i record possono arrivare da uno shard remoto).
  void upsert(Map<String, Object?> palette) {
    _db.execute(
      '''INSERT INTO palettes (id, name, seed_hex, colors_json, simple_json, is_preset, version, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           name = excluded.name,
           seed_hex = excluded.seed_hex,
           colors_json = excluded.colors_json,
           simple_json = excluded.simple_json,
           is_preset = excluded.is_preset,
           version = excluded.version,
           updated_at = excluded.updated_at''',
      [
        palette['id'],
        palette['name'],
        palette['seed_hex'],
        palette['colors_json'],
        palette['simple_json'],
        palette['is_preset'] ?? 0,
        palette['version'] ?? 1,
        palette['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  void delete(String id) {
    _db.execute('DELETE FROM palettes WHERE id = ?', [id]);
  }
}
