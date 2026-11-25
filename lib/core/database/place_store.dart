import 'package:sqlite3/sqlite3.dart';

/// I **posti già usati**, per i suggerimenti del campo «Posizione».
///
/// La domanda è «quali posizioni ho già scritto?» e la risposta la sa il
/// database meglio di noi: `DISTINCT` su due tabelle, ordinate, una query sola.
/// Leggere tutti gli eventi e tutti i todo per poi deduplicare in Dart
/// significherebbe costruire due liste intere per riempire una tendina.
class PlaceStore {
  PlaceStore(this._db);

  final Database _db;

  List<String> usedPlaces() {
    final rows = _db.select('''
      SELECT place FROM (
        SELECT DISTINCT location AS place FROM events
          WHERE COALESCE(location, '') != ''
        UNION
        SELECT DISTINCT location AS place FROM todos
          WHERE COALESCE(location, '') != ''
      ) ORDER BY place COLLATE NOCASE
    ''');
    return [for (final row in rows) row['place'] as String];
  }
}
