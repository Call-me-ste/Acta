import 'package:sqlite3/sqlite3.dart';

/// Il collegamento fra una nota e un evento/todo.
///
/// L'`id` è composto (`nota|tipo|elemento`) perché il sync e l'outbox hanno
/// bisogno di una chiave sola, mentre il database tiene anche la coppia logica
/// `(nota, tipo, elemento)`.
class NoteLink {
  const NoteLink({
    required this.id,
    required this.noteId,
    required this.entityType,
    required this.entityId,
    this.version = 1,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String noteId;

  /// `event` oppure `todo`.
  final String entityType;
  final String entityId;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static String idFor(String noteId, String entityType, String entityId) =>
      '$noteId|$entityType|$entityId';

  factory NoteLink.fromRow(Row row) {
    return NoteLink(
      id: row['id'] as String,
      noteId: row['note_id'] as String,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      version: row['version'] as int? ?? 1,
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
    );
  }

  Map<String, Object?> toParams() {
    return {
      'id': id,
      'note_id': noteId,
      'entity_type': entityType,
      'entity_id': entityId,
      'version': version,
      if (createdAt != null) 'created_at': createdAt!.millisecondsSinceEpoch,
      if (updatedAt != null) 'updated_at': updatedAt!.millisecondsSinceEpoch,
    };
  }

  static DateTime? _date(Object? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis as int);
}
