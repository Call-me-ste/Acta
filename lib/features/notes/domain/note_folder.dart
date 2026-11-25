import 'package:sqlite3/sqlite3.dart';

/// Una cartella di note. `colorIndex` è l'indice in `EventPalette`.
class NoteFolder {
  const NoteFolder({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.sortOrder = 0,
    this.pinned = false,
    this.version = 1,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int colorIndex;
  final int sortOrder;
  final bool pinned;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NoteFolder.fromRow(Row row) {
    return NoteFolder(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      colorIndex: row['color_index'] as int? ?? 0,
      sortOrder: row['sort_order'] as int? ?? 0,
      pinned: (row['pinned'] as int? ?? 0) == 1,
      version: row['version'] as int? ?? 1,
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
    );
  }

  Map<String, Object?> toParams() {
    return {
      'id': id,
      'name': name,
      'color_index': colorIndex,
      'sort_order': sortOrder,
      'pinned': pinned ? 1 : 0,
      'version': version,
      if (createdAt != null) 'created_at': createdAt!.millisecondsSinceEpoch,
      if (updatedAt != null) 'updated_at': updatedAt!.millisecondsSinceEpoch,
    };
  }

  NoteFolder copyWith({
    String? name,
    int? colorIndex,
    int? sortOrder,
    bool? pinned,
    int? version,
    DateTime? updatedAt,
  }) {
    return NoteFolder(
      id: id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      sortOrder: sortOrder ?? this.sortOrder,
      pinned: pinned ?? this.pinned,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _date(Object? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis as int);
}
