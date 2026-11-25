import 'dart:convert';

import 'hash.dart';

/// Un file di shard, come lo descrive il manifest.
class ShardEntry {
  const ShardEntry({
    required this.path,
    required this.entity,
    required this.month,
    required this.part,
    required this.records,
    required this.bytes,
    required this.checksum,
    required this.updatedAt,
  });

  final String path;
  final String entity;

  /// `YYYY-MM` del momento in cui lo shard è stato scritto.
  final String month;

  /// Progressivo dentro il mese (1, 2, …) quando la rotazione lo spezza.
  final int part;

  final int records;

  /// Byte **compresi** effettivamente salvati, più il checksum dei byte
  /// compressi: è quello che si confronta al momento di leggere.
  final int bytes;
  final String checksum;

  final DateTime updatedAt;

  factory ShardEntry.fromJson(Map<String, Object?> json) {
    return ShardEntry(
      path: json['path'] as String,
      entity: json['entity'] as String,
      month: json['month'] as String,
      part: json['part'] as int,
      records: json['records'] as int,
      bytes: json['bytes'] as int,
      checksum: json['checksum'] as String,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'path': path,
      'entity': entity,
      'month': month,
      'part': part,
      'records': records,
      'bytes': bytes,
      'checksum': checksum,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }
}

/// L'indice di quello che sta sul gateway: quali shard esistono, quanto sono
/// grandi e quale impronta hanno.
///
/// Si legge con **una** richiesta, ed è il primo filtro del pull: se il suo
/// cursore non è cambiato dall'ultima volta, non c'è niente da scaricare.
class SyncManifest {
  const SyncManifest({required this.generatedAt, required this.shards});

  static const String filePath = 'manifest.json';
  static const int formatVersion = 1;

  final DateTime generatedAt;
  final List<ShardEntry> shards;

  static SyncManifest empty() {
    return SyncManifest(
      generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      shards: const [],
    );
  }

  /// Impronta del contenuto: due manifest con gli stessi shard hanno lo stesso
  /// cursore, e il pull può fermarsi subito.
  String get cursor => fnv1a64Hex(utf8.encode(jsonEncode(_shardsJson())));

  List<Map<String, Object?>> _shardsJson() {
    return shards.map((entry) => entry.toJson()).toList();
  }

  Map<String, Object?> toJson() {
    return {
      'v': formatVersion,
      'generatedAt': generatedAt.millisecondsSinceEpoch,
      'checksum': cursor,
      'shards': _shardsJson(),
    };
  }

  List<int> encode() => utf8.encode(jsonEncode(toJson()));

  static SyncManifest decode(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Manifest: la radice deve essere un oggetto');
    }
    final json = decoded.cast<String, Object?>();
    if (json['v'] != formatVersion) {
      throw FormatException('Manifest di versione ${json['v']} non supportata');
    }

    final manifest = SyncManifest(
      generatedAt:
          DateTime.fromMillisecondsSinceEpoch(json['generatedAt'] as int),
      shards: (json['shards'] as List)
          .map((entry) =>
              ShardEntry.fromJson((entry as Map).cast<String, Object?>()))
          .toList(),
    );
    if (json['checksum'] != manifest.cursor) {
      throw const FormatException('Manifest corrotto: checksum non coerente');
    }
    return manifest;
  }

  /// L'ultimo shard di quell'entità: è quello a cui si appende. L'ordine della
  /// lista è l'ordine di scrittura, quindi "ultimo" vuol dire "corrente".
  ShardEntry? latestFor(String entity) {
    for (final entry in shards.reversed) {
      if (entry.entity == entity) return entry;
    }
    return null;
  }

  SyncManifest withEntry(ShardEntry entry) {
    return SyncManifest(
      generatedAt: DateTime.now(),
      shards: [
        ...shards.where((existing) =>
            existing.entity != entry.entity ||
            existing.month != entry.month ||
            existing.part != entry.part),
        entry,
      ],
    );
  }
}
