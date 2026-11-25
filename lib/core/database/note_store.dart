import 'package:sqlite3/sqlite3.dart';

/// Le note: lettura, ricerca e scrittura.
///
/// Sta in un file suo perche' `DatabaseService` ha un budget di righe
/// (test/architecture_test.dart) e perche' "come si legge una nota" e' una cosa
/// che le note si portano dietro: la ricerca, l'ordine, e (piu' avanti) le
/// cartelle e le immagini.
class NoteStore {
  NoteStore(this._db);

  final Database _db;

  List<Row> all() {
    return _db.select('SELECT * FROM notes ORDER BY updated_at DESC');
  }

  Row? byId(String id) =>
      _db.select('SELECT * FROM notes WHERE id = ?', [id]).firstOrNull;

  List<Row> search(String query) {
    return _db.select(
      'SELECT * FROM notes WHERE title LIKE ? OR content LIKE ?',
      ['%$query%', '%$query%'],
    );
  }

  void insert(Map<String, Object?> note) {
    _db.execute(
      '''INSERT INTO notes
           (id, title, content, pinned, folder_id, version, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [
        note['id'],
        note['title'] ?? '',
        note['content'] ?? '',
        note['pinned'] ?? 0,
        note['folder_id'],
        note['version'] ?? 1,
        note['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  void update(Map<String, Object?> note) {
    _db.execute(
      'UPDATE notes SET title=?, content=?, pinned=?, folder_id=?, version=?, '
      'updated_at=? WHERE id=?',
      [
        note['title'] ?? '',
        note['content'] ?? '',
        note['pinned'] ?? 0,
        note['folder_id'],
        note['version'] ?? 1,
        note['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
        note['id'],
      ],
    );
  }

  void delete(String id) {
    _db.execute('DELETE FROM notes WHERE id = ?', [id]);
  }

  List<Row> linksOfNote(String noteId) {
    return _db.select(
      'SELECT * FROM note_links WHERE note_id = ? ORDER BY created_at DESC',
      [noteId],
    );
  }

  List<Row> linksOfEntity(String entityType, String entityId) {
    return _db.select(
      'SELECT * FROM note_links WHERE entity_type = ? AND entity_id = ? '
      'ORDER BY created_at DESC',
      [entityType, entityId],
    );
  }

  Row? linkById(String id) {
    final rows = _db.select('SELECT * FROM note_links WHERE id = ?', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  void insertLink(Map<String, Object?> link) {
    _db.execute(
      '''INSERT INTO note_links
           (id, note_id, entity_type, entity_id, version, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [
        link['id'],
        link['note_id'],
        link['entity_type'],
        link['entity_id'],
        link['version'] ?? 1,
        link['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
        link['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  void deleteLink(String id) {
    _db.execute('DELETE FROM note_links WHERE id = ?', [id]);
  }

  List<Row> allFolders() {
    return _db.select(
      'SELECT * FROM note_folders ORDER BY sort_order, name COLLATE NOCASE',
    );
  }

  void insertFolder(Map<String, Object?> folder) {
    _db.execute(
      '''INSERT INTO note_folders
           (id, name, color_index, sort_order, pinned, version, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        folder['id'],
        folder['name'] ?? '',
        folder['color_index'] ?? 0,
        folder['sort_order'] ?? 0,
        folder['pinned'] ?? 0,
        folder['version'] ?? 1,
        folder['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
        folder['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  void updateFolder(Map<String, Object?> folder) {
    _db.execute(
      'UPDATE note_folders SET name=?, color_index=?, sort_order=?, pinned=?, '
      'version=?, updated_at=? WHERE id=?',
      [
        folder['name'] ?? '',
        folder['color_index'] ?? 0,
        folder['sort_order'] ?? 0,
        folder['pinned'] ?? 0,
        folder['version'] ?? 1,
        folder['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
        folder['id'],
      ],
    );
  }

  void deleteFolder(String id) {
    _db.execute('DELETE FROM note_folders WHERE id = ?', [id]);
  }
}
