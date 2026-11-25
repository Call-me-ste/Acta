import 'package:sqlite3/sqlite3.dart';

import '../../core/categories/category_ids.dart';

/// Le categorie: la libreria, piu' le due operazioni che toccano gli elementi.
///
/// La scrittura e' esplicita colonna per colonna, come per le palette: i record
/// possono arrivare da uno shard remoto e non devono finire interpolati in SQL.
/// Il nome della **tabella** invece viene da [itemTables], un elenco chiuso: non
/// arriva mai dall'esterno.
class CategoryStore {
  CategoryStore(this._db);

  final Database _db;

  /// Le due tabelle che portano `category_ids`, con l'entita' di sync
  /// corrispondente. Un elenco chiuso: qui dentro ci finisce solo roba nostra.
  static const Map<String, String> itemTables = {
    'events': 'event',
    'todos': 'todo',
  };

  List<Row> all() {
    return _db.select('SELECT * FROM categories ORDER BY name COLLATE NOCASE');
  }

  void upsert(Map<String, Object?> category) {
    _db.execute(
      '''INSERT INTO categories (id, name, emoji, color_hex, version, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           name = excluded.name,
           emoji = excluded.emoji,
           color_hex = excluded.color_hex,
           version = excluded.version,
           updated_at = excluded.updated_at''',
      [
        category['id'],
        category['name'],
        category['emoji'] ?? '',
        category['color_hex'] ?? '',
        category['version'] ?? 1,
        category['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  void delete(String id) {
    _db.execute('DELETE FROM categories WHERE id = ?', [id]);
  }

  /// La categoria con quel nome, se c'e' (senza badare a maiuscole): serve alla
  /// conversione della vecchia colonna e a non creare doppioni a mano.
  Row? byName(String name) {
    final rows = _db.select(
      'SELECT * FROM categories WHERE name = ? COLLATE NOCASE LIMIT 1',
      [name],
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Gli elementi che usano una categoria, con gli id che hanno adesso.
  ///
  /// Si legge la colonna e si decodifica in Dart: il confronto su un campo di
  /// testo con separatori non si puo' fare in SQL senza rischiare che un id che
  /// e' prefisso di un altro dia un falso positivo.
  List<({String table, String entity, String id, List<String> ids})> itemsUsing(
    String categoryId,
  ) {
    final found =
        <({String table, String entity, String id, List<String> ids})>[];
    for (final entry in itemTables.entries) {
      for (final row
          in _db.select('SELECT id, category_ids FROM ${entry.key}')) {
        final ids = decodeCategoryIds(row['category_ids']);
        if (!ids.contains(categoryId)) continue;
        found.add((
          table: entry.key,
          entity: entry.value,
          id: row['id'] as String,
          ids: ids,
        ));
      }
    }
    return found;
  }

  /// Scrive gli id delle categorie di un elemento e avanza il clock, in una
  /// istruzione sola: `version` e `updated_at` devono muoversi **insieme**,
  /// perche' il sync confronta proprio quella coppia.
  void setItemCategoryIds({
    required String table,
    required String id,
    required String encoded,
    required int version,
    required DateTime updatedAt,
  }) {
    final known = itemTables.containsKey(table);
    if (!known) throw ArgumentError('Tabella sconosciuta: $table');
    _db.execute(
      'UPDATE $table SET category_ids = ?, version = ?, updated_at = ? WHERE id = ?',
      [encoded, version, updatedAt.millisecondsSinceEpoch, id],
    );
  }

  /// La riga intera di un elemento: e' il payload che va in outbox, perche' il
  /// sync spedisce record completi e non differenze.
  Map<String, Object?>? rowOf(String table, String id) {
    if (!itemTables.containsKey(table)) {
      throw ArgumentError('Tabella sconosciuta: $table');
    }
    final rows = _db.select('SELECT * FROM $table WHERE id = ?', [id]);
    return rows.isEmpty ? null : Map<String, Object?>.from(rows.first);
  }

  /// I todo con la vecchia colonna `category` piena: testo libero scritto prima
  /// che le categorie esistessero.
  List<Row> legacyTodoRows() {
    return _db.select(
      "SELECT id, category FROM todos WHERE TRIM(COALESCE(category, '')) != ''",
    );
  }

  /// Svuota la vecchia colonna dopo la conversione: e' quello che rende la
  /// conversione idempotente (al secondo avvio non trova piu' niente).
  void clearLegacyCategory(String table, String id) {
    if (!itemTables.containsKey(table)) {
      throw ArgumentError('Tabella sconosciuta: $table');
    }
    _db.execute("UPDATE $table SET category = '' WHERE id = ?", [id]);
  }
}
