import 'dart:convert';
import 'dart:io';

import 'sync_record.dart';

/// Codifica di uno shard: **una riga JSON per record**, il tutto compreso con
/// gzip (codec della stdlib, nessuna dipendenza in più).
///
/// La rotazione è il cuore della faccenda: uno shard non supera mai le soglie
/// qui sotto, quindi il costo di un sync è proporzionale a ciò che è cambiato e
/// **non** a quanto possiedi. In v2 c'era un unico JSON con tutto dentro: ogni
/// sync ricaricava l'intero archivio, ed è per questo che diventava un problema.
class ShardCodec {
  const ShardCodec._();

  static const int maxRecordsPerShard = 500;
  static const int maxUncompressedBytes = 256 * 1024;

  static List<int> encode(List<SyncRecord> records) {
    final buffer = StringBuffer();
    for (final record in records) {
      buffer.writeln(record.toLine());
    }
    return gzip.encode(utf8.encode(buffer.toString()));
  }

  static List<SyncRecord> decode(List<int> bytes) {
    if (bytes.isEmpty) return const [];
    final text = utf8.decode(gzip.decode(bytes));
    return text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map(SyncRecord.fromLine)
        .toList();
  }

  static bool isFull(List<SyncRecord> records) {
    return records.length >= maxRecordsPerShard ||
        uncompressedBytes(records) >= maxUncompressedBytes;
  }

  /// Dimensione dei record *prima* della compressione: è la soglia che decide
  /// la rotazione, così non dipende dal rapporto di compressione del momento.
  static int uncompressedBytes(List<SyncRecord> records) {
    var total = 0;
    for (final record in records) {
      total += utf8.encode(record.toLine()).length + 1; // +1 per il newline
    }
    return total;
  }

  /// `todo/2026-09.jsonl.gz`, poi `todo/2026-09.002.jsonl.gz` se il mese è
  /// stato spezzato dalla rotazione.
  static String shardPath({
    required String entity,
    required String month,
    required int part,
  }) {
    final suffix = part <= 1 ? '' : '.${part.toString().padLeft(3, '0')}';
    return '$entity/$month$suffix.jsonl.gz';
  }

  static String monthKey(DateTime when) {
    final year = when.year.toString().padLeft(4, '0');
    final month = when.month.toString().padLeft(2, '0');
    return '$year-$month';
  }
}
