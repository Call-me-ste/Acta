import 'package:sqlite3/sqlite3.dart';

void applyNoteAttachmentSchema(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS note_attachments (
      id TEXT PRIMARY KEY,
      note_id TEXT NOT NULL,
      blob_id TEXT NOT NULL,
      metadata BLOB NOT NULL
    )
  ''');
  db.execute(
    'CREATE INDEX IF NOT EXISTS note_attachments_note ON note_attachments(note_id)',
  );
}
