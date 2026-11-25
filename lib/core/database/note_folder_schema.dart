import 'package:sqlite3/sqlite3.dart';

/// Schema delle cartelle Note, separato per tenere `schema.dart` sotto le 300
/// righe. La creazione è idempotente e la colonna `folder_id` è additiva.
void ensureNoteFolders(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS note_folders (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL DEFAULT '',
      color_index INTEGER DEFAULT 0,
      sort_order INTEGER DEFAULT 0,
      pinned INTEGER DEFAULT 0,
      version INTEGER DEFAULT 1,
      created_at INTEGER DEFAULT (strftime('%s','now') * 1000),
      updated_at INTEGER DEFAULT (strftime('%s','now') * 1000)
    )
  ''');
  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_note_folders_sort
      ON note_folders (sort_order, name)
  ''');
  final haFolderId = db
      .select('PRAGMA table_info(notes)')
      .any((row) => row['name'] == 'folder_id');
  if (!haFolderId) {
    db.execute('ALTER TABLE notes ADD COLUMN folder_id TEXT');
  }
  final haPinned = db
      .select('PRAGMA table_info(note_folders)')
      .any((row) => row['name'] == 'pinned');
  if (!haPinned) {
    db.execute(
      'ALTER TABLE note_folders ADD COLUMN pinned INTEGER DEFAULT 0',
    );
  }
}
