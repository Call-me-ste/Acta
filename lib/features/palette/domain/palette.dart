import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// Una palette: il seed che genera il tema e i colori degli elementi.
///
/// I colori sono **stringhe hex**, non `Color`: così il modello resta puro Dart
/// e la logica (core/ e features/) continua a non dipendere dai widget — è la
/// regola che permette di condividere tutto fra mobile e desktop.
class Palette {
  const Palette({
    required this.id,
    required this.name,
    required this.seedHex,
    required this.colors,
    this.simpleColors = const {},
    this.isPreset = false,
    this.version = 1,
    this.updatedAt,
  });

  final String id;
  final String name;

  /// Il colore da cui il tema genera chiaro e scuro (`ColorScheme.fromSeed`).
  final String seedHex;

  /// I colori degli elementi, come `#rrggbb`.
  final List<String> colors;

  /// I colori del modo semplice, per ruolo: vedi [simpleRoles].
  ///
  /// Vuoto vuol dire «come prima»: il tema lo genera tutto il seed. Questi si
  /// applicano **sopra** lo schema generato, e valgono in chiaro come in scuro —
  /// l'utente li sceglie una volta, non due.
  final Map<String, String> simpleColors;

  /// I ruoli del modo semplice: fondo, superfici, testo. Sono gli unici che si
  /// toccano lì; contenitori, stati e contrasti restano quelli che il seed sa
  /// fare, e **l'accento non c'e' piu'**: il colore del tema e' il colore scelto
  /// (`seedHex`), quindi un accento separato sarebbe un comando che non comanda
  /// (era la segnalazione: «scelgo un rosso acceso e mi mette quasi un rosa»).
  static const List<String> simpleRoles = [
    'surface',
    'surfaceContainer',
    'onSurface',
  ];

  /// `true` = read-only: per personalizzarla si duplica. Impedisce che un preset
  /// venga rotto per sbaglio (e che i due device non siano d'accordo su cosa sia
  /// un preset).
  final bool isPreset;

  final int version;
  final DateTime? updatedAt;

  factory Palette.fromRow(Row row) {
    return Palette(
      id: row['id'] as String,
      name: row['name'] as String,
      seedHex: row['seed_hex'] as String,
      colors: _decodeColors(row['colors_json'] as String?),
      simpleColors: _decodeSimple(row['simple_json'] as String?),
      isPreset: (row['is_preset'] as int? ?? 0) == 1,
      version: row['version'] as int? ?? 1,
      updatedAt: _dateTimeOrNull(row['updated_at']),
    );
  }

  Map<String, Object?> toParams() {
    return {
      'id': id,
      'name': name,
      'seed_hex': seedHex,
      'colors_json': jsonEncode(colors),
      'simple_json': jsonEncode(simpleColors),
      'is_preset': isPreset ? 1 : 0,
      'version': version,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Il colore per indice, in modo **ciclico**: togliere un colore da una
  /// palette non deve far sparire gli elementi che ne citavano uno in più.
  String colorAt(int index) {
    if (colors.isEmpty) return seedHex;
    final length = colors.length;
    final safe = ((index % length) + length) % length;
    return colors[safe];
  }

  Palette copyWith({
    String? name,
    String? seedHex,
    List<String>? colors,
    Map<String, String>? simpleColors,
    bool? isPreset,
    int? version,
    DateTime? updatedAt,
  }) {
    return Palette(
      id: id,
      name: name ?? this.name,
      seedHex: seedHex ?? this.seedHex,
      colors: colors ?? this.colors,
      simpleColors: simpleColors ?? this.simpleColors,
      isPreset: isPreset ?? this.isPreset,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static List<String> _decodeColors(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map((value) => value.toString()).toList();
    } on FormatException {
      // Palette illeggibile: meglio una palette senza colori (che ricade sul
      // seed) che un'app che non parte.
      return const [];
    }
  }

  /// I quattro colori del modo semplice, tollerante come `_decodeColors`: un
  /// JSON storto diventa «nessun colore», cioè il tema dal seed, invece di
  /// un'app che non parte.
  static Map<String, String> _decodeSimple(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final result = <String, String>{};
      for (final role in simpleRoles) {
        final value = decoded[role];
        if (value is String && value.isNotEmpty) result[role] = value;
      }
      return result;
    } on FormatException {
      return const {};
    }
  }

  static DateTime? _dateTimeOrNull(Object? millis) {
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis as int);
  }
}
