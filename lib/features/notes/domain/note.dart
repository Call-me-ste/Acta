import 'package:sqlite3/sqlite3.dart';

/// Una nota.
///
/// Come gli altri modelli porta `version` e `updatedAt`: sono il clock con cui
/// il sync risolve i conflitti. `created_at` lo gestisce il database.
class Note {
  const Note({
    required this.id,
    this.title = '',
    this.content = '',
    this.pinned = false,
    this.folderId,
    this.version = 1,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final bool pinned;
  final String? folderId;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Note.fromRow(Row row) {
    return Note(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      content: (row['content'] as String?) ?? '',
      pinned: (row['pinned'] as int? ?? 0) == 1,
      folderId: row['folder_id'] as String?,
      version: row['version'] as int? ?? 1,
      createdAt: _dateTimeOrNull(row['created_at']),
      updatedAt: _dateTimeOrNull(row['updated_at']),
    );
  }

  Map<String, Object?> toParams() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'pinned': pinned ? 1 : 0,
      'folder_id': folderId,
      'version': version,
      if (updatedAt != null) 'updated_at': updatedAt!.millisecondsSinceEpoch,
    };
  }

  Note copyWith({
    String? title,
    String? content,
    bool? pinned,
    String? folderId,
    bool removeFolder = false,
    int? version,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      pinned: pinned ?? this.pinned,
      folderId: removeFolder ? null : (folderId ?? this.folderId),
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _dateTimeOrNull(Object? millis) {
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis as int);
  }
}
