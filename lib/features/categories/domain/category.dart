import 'package:sqlite3/sqlite3.dart';

/// Una categoria: un'etichetta con un nome, un'emoji e un colore.
///
/// Come le palette, la libreria delle categorie **viaggia** fra i device
/// (`version` + `updated_at` sono il clock con cui il sync risolve i conflitti),
/// mentre l'assegnazione a un evento o a un todo sta nella colonna
/// `category_ids` dell'elemento: un elemento appartiene a una categoria, la
/// categoria non tiene l'elenco dei suoi elementi.
class ItemCategory {
  const ItemCategory({
    required this.id,
    required this.name,
    this.emoji = '',
    this.colorHex = '',
    this.version = 1,
    this.updatedAt,
  });

  final String id;
  final String name;

  /// L'emoji scelta a mano, vuota se non c'e'. Il nome e' la cosa che si legge:
  /// l'emoji aiuta a riconoscerla a colpo d'occhio, non e' un obbligo.
  final String emoji;

  /// Colore `#rrggbb`, vuoto = lo decide il tema (il colore dell'elemento).
  final String colorHex;

  final int version;
  final DateTime? updatedAt;

  factory ItemCategory.fromRow(Row row) {
    return ItemCategory(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      emoji: (row['emoji'] as String?) ?? '',
      colorHex: (row['color_hex'] as String?) ?? '',
      version: row['version'] as int? ?? 1,
      updatedAt: _dateTimeOrNull(row['updated_at']),
    );
  }

  Map<String, Object?> toParams() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'color_hex': colorHex,
      'version': version,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  ItemCategory copyWith({
    String? name,
    String? emoji,
    String? colorHex,
    int? version,
    DateTime? updatedAt,
  }) {
    return ItemCategory(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _dateTimeOrNull(Object? millis) {
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis as int);
  }
}
