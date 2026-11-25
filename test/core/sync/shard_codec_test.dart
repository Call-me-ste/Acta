import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/sync/hash.dart';
import 'package:planner/core/sync/shard_codec.dart';
import 'package:planner/core/sync/sync_manifest.dart';
import 'package:planner/core/sync/sync_record.dart';

SyncRecord _record(int index) {
  return SyncRecord(
    entity: 'todo',
    id: 'id-$index',
    operation: SyncOperation.upsert,
    version: 1,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1789000000000 + index),
    data: {'id': 'id-$index', 'title': 'Todo $index', 'version': 1},
  );
}

void main() {
  group('hash', () {
    test('cambia se cambia un byte, e resta stabile altrimenti', () {
      final bytes = utf8.encode('contenuto di prova');
      final same = utf8.encode('contenuto di prova');
      final changed = utf8.encode('contenuto di provb');

      expect(fnv1a64Hex(bytes), fnv1a64Hex(same));
      expect(fnv1a64Hex(bytes), isNot(fnv1a64Hex(changed)));
      // 64 bit = 16 cifre esadecimali, sempre
      expect(fnv1a64Hex(bytes), hasLength(16));
    });
  });

  group('shard', () {
    test('round trip: i record tornano identici', () {
      final records = List.generate(25, _record);

      final decoded = ShardCodec.decode(ShardCodec.encode(records));

      expect(decoded, hasLength(25));
      expect(decoded.first.id, 'id-0');
      expect(decoded.last.id, 'id-24');
      expect(decoded.first.data['title'], 'Todo 0');
      // la compressione riduce davvero: non è un dettaglio, è metà del punto
      expect(ShardCodec.encode(records).length,
          lessThan(ShardCodec.uncompressedBytes(records)));
    });

    test('un delete non porta dati con sé', () {
      final record = SyncRecord(
        entity: 'todo',
        id: 't1',
        operation: SyncOperation.delete,
        version: 4,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      );

      final revived = SyncRecord.fromLine(record.toLine());

      expect(revived.operation, SyncOperation.delete);
      expect(revived.data, isEmpty);
      expect(revived.version, 4);
    });

    test('la rotazione scatta sui record e sui byte', () {
      final small = List.generate(ShardCodec.maxRecordsPerShard - 1, _record);
      expect(ShardCodec.isFull(small), isFalse);
      expect(ShardCodec.isFull([...small, _record(99)]), isTrue);

      // Molti record *lunghi* fanno scattare la soglia dei byte prima di quella
      // dei record: è voluto, così lo shard non cresce comunque.
      final fat = List.generate(
        20,
        (index) => SyncRecord(
          entity: 'note',
          id: 'n$index',
          operation: SyncOperation.upsert,
          version: 1,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          data: {'content': 'x' * (ShardCodec.maxUncompressedBytes ~/ 10)},
        ),
      );
      expect(ShardCodec.isFull(fat), isTrue);
    });

    test('i nomi degli shard seguono il mese', () {
      expect(
        ShardCodec.shardPath(entity: 'todo', month: '2026-09', part: 1),
        'todo/2026-09.jsonl.gz',
      );
      expect(
        ShardCodec.shardPath(entity: 'todo', month: '2026-09', part: 2),
        'todo/2026-09.002.jsonl.gz',
      );
      expect(ShardCodec.monthKey(DateTime(2026, 9, 3)), '2026-09');
      expect(ShardCodec.monthKey(DateTime(2026, 10, 1)), '2026-10');
    });
  });

  group('manifest', () {
    test('round trip e cursore stabile', () {
      final manifest = SyncManifest.empty().withEntry(
        ShardEntry(
          path: 'todo/2026-09.jsonl.gz',
          entity: 'todo',
          month: '2026-09',
          part: 1,
          records: 2,
          bytes: 100,
          checksum: fnv1a64Hex(utf8.encode('x')),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(5),
        ),
      );

      final revived = SyncManifest.decode(manifest.encode());

      expect(revived.shards.single.path, 'todo/2026-09.jsonl.gz');
      expect(revived.cursor, manifest.cursor);
    });

    test('un manifest manomesso viene rifiutato', () {
      final manifest = SyncManifest.empty().withEntry(
        ShardEntry(
          path: 'todo/2026-09.jsonl.gz',
          entity: 'todo',
          month: '2026-09',
          part: 1,
          records: 1,
          bytes: 10,
          checksum: fnv1a64Hex(utf8.encode('x')),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(5),
        ),
      );

      // Un byte cambiato dentro lo shard dichiarato: il checksum del manifest
      // non torna più, e il pull si ferma invece di applicare mezze verità.
      final json = jsonDecode(utf8.decode(manifest.encode())) as Map;
      (json['shards'] as List).first['checksum'] = '0' * 16;

      expect(
        () => SyncManifest.decode(utf8.encode(jsonEncode(json))),
        throwsA(isA<FormatException>()),
      );
    });

    test('latestFor prende l\'ultimo shard di quell\'entità', () {
      final base = SyncManifest.empty();
      final first = base.withEntry(
        ShardEntry(
          path: 'todo/2026-09.jsonl.gz',
          entity: 'todo',
          month: '2026-09',
          part: 1,
          records: 1,
          bytes: 1,
          checksum: 'a',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
      final second = first.withEntry(
        ShardEntry(
          path: 'todo/2026-09.002.jsonl.gz',
          entity: 'todo',
          month: '2026-09',
          part: 2,
          records: 1,
          bytes: 1,
          checksum: 'b',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
        ),
      );

      expect(second.latestFor('todo')!.path, 'todo/2026-09.002.jsonl.gz');
      expect(second.latestFor('note'), isNull);
    });
  });
}
