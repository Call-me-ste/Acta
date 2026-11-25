import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:planner/core/database/database_files.dart';
import 'package:planner/core/database/database_service.dart';

/// La manutenzione dei **file**: lo spazio che si restituisce e il modo per
/// farlo.
///
/// E' la parte che si poteva sbagliare in silenzio: `PRAGMA incremental_vacuum`
/// **sembra** la via per restituire lo spazio, e su un database con
/// `auto_vacuum` spento (cioe' tutti quelli creati finora) e' un comando che non
/// fa niente. Misurato: 160 pagine libere su un file da 852 KB, e dopo il comando
/// le pagine libere erano ancora 160. Lo spazio lo restituisce il `VACUUM`.
void main() {
  late Directory radice;
  late DatabaseService db;

  setUp(() async {
    radice = Directory.systemTemp.createTempSync('planner-file');
    db = DatabaseService();
    await db.init(dbPath: p.join(radice.path, 'planner.db'));
  });

  tearDown(() {
    db.close();
    if (radice.existsSync()) radice.deleteSync(recursive: true);
  });

  /// Un database cresciuto come nella vita vera: tante scritture, poi la coda
  /// compattata (cioe' righe cancellate che lasciano pagine libere).
  void cresci({int giri = 10, int elementi = 200}) {
    var operazione = 0;
    for (var giro = 0; giro < giri; giro++) {
      for (var i = 0; i < elementi; i++) {
        operazione++;
        final riga = <String, Object?>{
          'id': 't$i',
          'title': 'Todo numero $i con un titolo di lunghezza normale',
          'completed': giro % 2,
          'priority': i % 4,
          'due_date': DateTime(2026, 9, 23).millisecondsSinceEpoch,
          'note': 'Una nota di lunghezza normale, come quelle che si scrivono',
          'version': giro + 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };
        if (giro == 0) {
          db.insertTodo(riga);
        } else {
          db.updateTodo(riga);
        }
        db.outbox.enqueue(
          operationId: 'op-${operazione.toString().padLeft(5, '0')}',
          entity: 'todo',
          entityId: 't$i',
          operation: 'upsert',
          version: giro + 1,
          updatedAt: riga['updated_at'] as int,
          payload: riga,
        );
      }
    }
    db.checkpoint();
  }

  test('la compattazione toglie le righe in coda e restituisce lo spazio', () {
    cresci();
    final primaDelleRighe = db.outbox.pendingCount();
    expect(primaDelleRighe, 2000);

    final esito = db.compatta();

    expect(esito.righe, 1800,
        reason: 'dieci giri per elemento, uno solo resta');
    expect(db.outbox.pendingCount(), 200);
    expect(esito.byteDopo, lessThan(esito.bytePrima),
        reason: 'lo spazio torna al disco');
    // E il WAL non resta appeso: dopo la compattazione il file principale e'
    // tutto quello che serve.
    expect(db.dimensioni().wal, 0);
    expect(db.integrita(), 'ok');
  });

  /// Righe in coda **in piu'** per lo stesso elemento: e' esattamente quello che
  /// una compattazione toglierebbe (una resta sempre). Gli id delle operazioni sono
  /// diversi a ogni chiamata, altrimenti la seconda troverebbe la chiave occupata.
  var sporcature = 0;

  void sporcaLaCoda({int quante = 5}) {
    sporcature++;
    for (var i = 1; i <= quante; i++) {
      db.outbox.enqueue(
        operationId: 'sporca-$sporcature-$i',
        entity: 'todo',
        entityId: 't1',
        operation: 'upsert',
        version: i,
        updatedAt: i,
        payload: const {'id': 't1'},
      );
    }
  }

  group('compattazione automatica', () {
    test('non fa niente quando non c\'e\' niente da restituire', () {
      final esito = db.compattaSeServe();

      expect(esito, isNull);
      // E non scrive il flag: senza niente da fare, il prossimo avvio ricontrolla.
      expect(db.meta.get('lastCompactAt'), isNull);
    });

    test('dopo la finestra compatta, restituisce spazio e scrive il flag', () {
      cresci();
      final prima = db.dimensioni().database;

      final esito = db.compattaSeServe(adesso: DateTime(2026, 9, 23, 12));

      expect(esito, isNotNull);
      expect(esito!.righe, 1800, reason: 'dieci giri per elemento, uno resta');
      expect(esito.byteDopo, lessThan(prima));
      expect(db.outbox.pendingCount(), 200);
      expect(db.meta.get('lastCompactAt'), isNotNull);
      // Il giorno dopo non si ricompatta: la finestra e' di sette giorni.
      expect(db.compattaSeServe(adesso: DateTime(2026, 9, 24, 12)), isNull);
    });

    test('con forza compatta anche dentro la finestra', () {
      sporcaLaCoda();
      expect(
        db.compattaSeServe(adesso: DateTime(2026, 9, 23, 12)),
        isNotNull,
        reason: 'la prima volta c\'era qualcosa da fare',
      );

      sporcaLaCoda();
      expect(
        db.compattaSeServe(adesso: DateTime(2026, 9, 23, 13)),
        isNull,
        reason: 'un\'ora dopo, senza forza, non si tocca niente',
      );
      // All'esportazione si forza: la copia che esce deve essere quella buona.
      final forzata = db.compattaSeServe(
        forza: true,
        adesso: DateTime(2026, 9, 23, 13),
      );
      expect(forzata, isNotNull);
      // La seconda sporcata ha aggiunto cinque righe: la compattazione le toglie
      // tutte e lascia la piu' recente per elemento.
      expect(forzata!.righe, 5);
      expect(db.outbox.pendingCount(), 1);
    });

    test('compatta anche quando l\'unica cosa da fare e\' lo spazio', () {
      // Coda gia' compatta, ma il file ha pagine libere da restituire: e' il caso
      // di chi ha cancellato tanti elementi e non ha mai compattato.
      cresci();
      db.outbox.compact();
      db.checkpoint();
      expect(db.outbox.compactableCount(), 0);

      final esito = db.compattaSeServe(adesso: DateTime(2026, 9, 23, 12));

      expect(esito, isNotNull);
      expect(esito!.righe, 0);
      expect(esito.byteDopo, lessThan(esito.bytePrima));
    });
  });

  test(
      'la manutenzione una volta sola accende auto_vacuum e restituisce spazio',
      () {
    cresci();
    db.outbox.compact();
    db.checkpoint();
    // Le righe cancellate sono pagine libere: il file non si e' ancora rimpicciolito.
    final liberePrima =
        db.instance.select('PRAGMA freelist_count').first.values.first as int;
    expect(liberePrima, greaterThan(0));

    final esito = db.manutenzioneUnaTantum();

    expect(esito.byteDopo, lessThan(esito.bytePrima));
    expect(
      db.instance.select('PRAGMA auto_vacuum').first.values.first,
      2,
      reason: 'incrementale acceso (0 = spento)',
    );
    expect(db.instance.select('PRAGMA freelist_count').first.values.first, 0);
    expect(db.integrita(), 'ok');
  });

  test('la manutenzione non si ripete a ogni avvio', () {
    cresci();
    db.manutenzioneUnaTantum();

    // La seconda volta non fa niente: un `VACUUM` a ogni avvio su un database
    // grande si sente, e non serve a niente.
    final seconda = db.manutenzioneUnaTantum();

    expect(seconda.bytePrima, 0);
    expect(seconda.byteDopo, 0);
  });

  test('dopo la manutenzione la compattazione restituisce spazio da sola', () {
    cresci();
    db.manutenzioneUnaTantum();

    // Con `auto_vacuum` acceso lo spazio si restituisce anche senza riscrivere
    // tutto il file: e' il motivo per cui la manutenzione si fa una volta sola.
    final prima = db.dimensioni().database;
    db.outbox.compact();
    db.instance.execute('PRAGMA incremental_vacuum');
    db.checkpoint();

    expect(db.dimensioni().database, lessThan(prima));
  });
}
