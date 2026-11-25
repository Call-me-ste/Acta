import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// Cosa è successo a un record dall'ultimo sync.
enum SyncOperation {
  upsert,
  delete;

  static SyncOperation parse(String value) {
    return SyncOperation.values.firstWhere(
      (operation) => operation.name == value,
      orElse: () => throw FormatException('Operazione sconosciuta: $value'),
    );
  }
}

/// Un'operazione sincronizzabile: una riga di shard.
///
/// Porta con sé `version` e `updatedAt` perché sono il **clock** con cui si
/// decide chi vince quando due dispositivi hanno toccato la stessa entità:
/// niente orologi globali, niente server che arbitra.
class SyncRecord {
  const SyncRecord({
    required this.entity,
    required this.id,
    required this.operation,
    required this.version,
    required this.updatedAt,
    this.data = const {},
  });

  /// `event` | `todo` | `note` (e le famiglie che arriveranno).
  final String entity;
  final String id;
  final SyncOperation operation;
  final int version;
  final DateTime updatedAt;

  /// I parametri dell'entità, gli stessi che vanno in SQL. Vuoto per `delete`.
  final Map<String, Object?> data;

  factory SyncRecord.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    final updatedAt = json['updatedAt'];
    final rawData = json['data'];
    return SyncRecord(
      entity: json['entity'] as String,
      id: json['id'] as String,
      operation: SyncOperation.parse(json['op'] as String),
      version: version as int,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt as int),
      data:
          rawData == null ? const {} : (rawData as Map).cast<String, Object?>(),
    );
  }

  /// Costruisce il record da una riga dell'outbox.
  factory SyncRecord.fromOutboxRow(Row row) {
    final payload = jsonDecode(row['payload_json'] as String);
    return SyncRecord(
      entity: row['entity_type'] as String,
      id: row['entity_id'] as String,
      operation: SyncOperation.parse(row['operation'] as String),
      version: row['entity_version'] as int? ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['entity_updated_at'] as int? ?? 0,
      ),
      data: (payload as Map).cast<String, Object?>(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'v': 1,
      'entity': entity,
      'id': id,
      'op': operation.name,
      'version': version,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      if (operation == SyncOperation.upsert) 'data': data,
    };
  }

  String toLine() => jsonEncode(toJson());

  factory SyncRecord.fromLine(String line) {
    return SyncRecord.fromJson(
      (jsonDecode(line) as Map).cast<String, Object?>(),
    );
  }
}
