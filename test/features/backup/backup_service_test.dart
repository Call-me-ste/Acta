import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:planner/core/database/database_files.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/database/schema.dart';
import 'package:planner/core/sync/hash.dart';
import 'package:planner/features/backup/backup_service.dart';
import 'package:planner/features/backup/backup_verify.dart';
import 'package:planner/features/backup/domain/backup_file.dart';

/// Le copie, sul **disco vero**: database su file, cartella temporanea, file
/// scritti e riletti.
///
/// Perche' non bastano i test del modello: le tre cose che possono perdere dati
/// — una copia scritta a meta', una copia che non si riapre, un ripristino che
/// cancella prima di scrivere — esistono solo quando c'e' un file di mezzo.
void main() {
  late Directory radice;
  late Directory cartella;
  late DatabaseService db;
  late BackupService copie;

  /// Orologio finto: le copie si datano da sole, e con l'orologio vero due test
  /// nello stesso secondo si sovrascriverebbero a vicenda.
  var quando = DateTime(2026, 9, 23, 20, 0, 0);

  setUp(() async {
    radice = Directory.systemTemp.createTempSync('planner-copie');
    cartella = Directory(p.join(radice.path, 'copie'));
    quando = DateTime(2026, 9, 23, 20, 0, 0);

    db = DatabaseService();
    await db.init(dbPath: p.join(radice.path, 'planner.db'));
    copie = BackupService(
      db,
      cartella: cartella,
      adesso: () => quando,
      dispositivo: () => 'test',
    );
  });

  tearDown(() {
    db.close();
    if (radice.existsSync()) radice.deleteSync(recursive: true);
  });

  void evento(String id, {String titolo = 'Evento', int? updatedAt}) {
    db.insertEvent({
      'id': id,
      'title': titolo,
      'start_time': 1000,
      'end_time': 2000,
      'updated_at': updatedAt,
    });
  }

  File fileCopia(String nome) => File(p.join(cartella.path, nome));

  test('ripristina una copia esterna con le cartelle delle note', () async {
    evento('originale');
    db.notes.insertFolder({'id': 'cartella', 'name': 'Ricette'});
    db.notes.insert({'id': 'nota', 'title': 'Pane', 'folder_id': 'cartella'});
    final copia = await copie.snapshot(motivo: BackupReason.manuale);
    final esportata =
        await fileCopia(copia.name).copy(p.join(radice.path, 'esterno.db'));

    db.notes.deleteFolder('cartella');
    evento('nuovo');
    final sicurezza = await copie.ripristinaEsterna(esportata.path);

    expect(sicurezza.reason, BackupReason.preRipristino);
    expect(db.getEvents().single['id'], 'originale');
    expect(db.notes.allFolders().single['id'], 'cartella');
    expect(db.notes.all().single['folder_id'], 'cartella');
  });

  test('rifiuta un database di un’altra app prima di toccare i dati', () async {
    evento('da-tenere');
    final percorso = p.join(radice.path, 'estraneo.db');
    final estraneo = sqlite.sqlite3.open(percorso)
      ..execute('CREATE TABLE estranea (id TEXT)');
    estraneo.dispose();

    await expectLater(
        copie.ripristinaEsterna(percorso), throwsA(isA<BackupFallito>()));
    expect(db.getEvents().single['id'], 'da-tenere');
    expect(await copie.elenco(), isEmpty);
  });

  group('scrivere', () {
    test('la copia si scrive, si verifica e porta il suo foglio', () async {
      evento('e1');
      evento('e2');
      db.insertTodo({'id': 't1', 'title': 'Todo'});

      final copia = await copie.snapshot(motivo: BackupReason.manuale);

      expect(fileCopia(copia.name).existsSync(), isTrue);
      expect(fileCopia(BackupNaming.foglioDi(copia.name)).existsSync(), isTrue);
      expect(copia.verified, isTrue);
      expect(copia.createdAt, quando);
      expect(copia.reason, BackupReason.manuale);

      final foglio = copia.sidecar!;
      expect(foglio.counts, db.conteggi());
      expect(foglio.counts['events'], 2);
      expect(foglio.counts['todos'], 1);
      expect(
          foglio.checksum, fnv1a64Hex(fileCopia(copia.name).readAsBytesSync()));
      expect(foglio.device, 'test');
      expect(foglio.schemaVersion, schemaVersion);
    });

    test('due copie nello stesso secondo non si sovrascrivono', () async {
      final prima = await copie.snapshot();
      final seconda = await copie.snapshot();

      expect(prima.name, 'planner-20260923-200000.sqlite');
      expect(seconda.name, 'planner-20260923-200000-2.sqlite');
      expect(fileCopia(prima.name).existsSync(), isTrue);
      expect(fileCopia(seconda.name).existsSync(), isTrue);
    });

    test("l'elenco ignora i file estranei e ordina dal piu' recente", () async {
      final prima = await copie.snapshot();
      quando = quando.add(const Duration(hours: 3));
      final seconda = await copie.snapshot();

      // Un file di un'altra app, e un temporaneo rimasto da una scrittura
      // interrotta: non sono copie nostre e non si toccano.
      File(p.join(cartella.path, 'estraneo.sqlite')).writeAsStringSync('x');
      File(p.join(cartella.path, 'planner-20990101-000000.sqlite.tmp'))
          .writeAsStringSync('x');

      final elenco = await copie.elenco();

      expect(elenco.map((c) => c.name), [seconda.name, prima.name]);
    });

    test('le due copie di emergenza si alternano', () async {
      evento('e1');
      final prima = await copie.emergenza();
      final seconda = await copie.emergenza();

      expect(prima.name, BackupNaming.emergenzaA);
      expect(seconda.name, BackupNaming.emergenzaB);
      expect(prima.eEmergenza, isTrue);
      expect(seconda.reason, BackupReason.emergenza);
    });
  });

  group('ripristinare', () {
    test('i dati tornano quelli della copia, e i conteggi tornano con loro',
        () async {
      evento('e1', titolo: 'Prima della copia');
      db.insertTodo({'id': 't1', 'title': 'Todo di prima'});
      final copia = await copie.snapshot(motivo: BackupReason.manuale);
      final attesi = copia.sidecar!.counts;

      // Dopo la copia succede di tutto: una riga nuova, una cancellata, una
      // modificata. E' il caso vero — non si ripristina mai "subito dopo".
      evento('e2', titolo: 'Dopo la copia');
      db.deleteEvent('e1');
      db.insertTodo({'id': 't2', 'title': 'Todo dopo'});

      final sicurezza = await copie.ripristina(copia);

      expect(db.conteggi(), attesi);
      expect(db.getEvents().single['title'], 'Prima della copia');
      expect(db.getTodos().single['title'], 'Todo di prima');
      // La copia di sicurezza e' quello che c'era **prima** del ripristino:
      // senza, un ripristino sbagliato non si annulla.
      expect(sicurezza.reason, BackupReason.preRipristino);
      expect(sicurezza.sidecar!.counts['events'], 1);
      expect(sicurezza.sidecar!.counts['todos'], 2);
    });

    test('una copia corrotta non si usa e non tocca il database', () async {
      evento('e1', titolo: 'Da non perdere');
      final copia = await copie.snapshot();

      // Il caso vero: il file c'e', ma e' troncato (o un disco che sbaglia).
      fileCopia(copia.name).writeAsBytesSync([1, 2, 3, 4]);

      final esito = await copie.verifica(copia.name);
      expect(esito.ok, isFalse);
      expect(esito.problema, isNotNull);

      await expectLater(
        copie.ripristina(copia),
        throwsA(isA<BackupFallito>()),
      );
      expect(db.getEvents().single['title'], 'Da non perdere');
    });

    test('una copia di una versione piu\' nuova non si apre', () async {
      final copia = await copie.snapshot();

      // Un foglio scritto da una versione futura: le sue tabelle possono avere
      // colonne che qui non esistono, e "aprire per vedere" e' il modo di
      // perdere dati in silenzio.
      final foglio = BackupSidecar(
        appVersion: '9.9.9+99',
        schemaVersion: schemaVersion + 1,
        createdAt: quando,
        device: 'futuro',
        counts: const {},
        checksum: 'x',
        reason: BackupReason.automatica,
      );
      File(p.join(cartella.path, BackupNaming.foglioDi(copia.name)))
          .writeAsStringSync(jsonEncode(foglio.toJson()));

      final dalDisco = (await copie.elenco()).single;
      await expectLater(
        copie.ripristina(dalDisco),
        throwsA(
          isA<BackupFallito>().having(
            (e) => e.messaggio,
            'messaggio',
            contains('più nuova'),
          ),
        ),
      );
    });

    test('dopo un ripristino lo stato del sync si dimentica', () async {
      evento('e1');
      final copia = await copie.snapshot();

      // Lo stato che descrive il database di **prima**.
      db.meta.set('remote_cursor', 'cursore-vecchio');
      db.meta.set('shard:2026-09/eventi.jsonl.gz', 'applied');
      db.meta.set('altra-chiave', 'da-non-toccare');

      await copie.ripristina(copia);

      // Senza questa dimenticanza il dispositivo crederebbe di essere gia'
      // allineato e non tirerebbe giu' niente.
      expect(db.meta.get('remote_cursor'), isNull);
      expect(db.meta.get('shard:2026-09/eventi.jsonl.gz'), isNull);
      expect(db.meta.get('altra-chiave'), 'da-non-toccare');
    });

    test(
        'una copia piu\' vecchia non e\' un errore: manca la tabella, non i dati',
        () async {
      // Una copia di una versione in cui `categories` non esisteva ancora: si
      // verifica lo stesso, e si ripristina quello che c'e' dentro.
      cartella.createSync(recursive: true);
      final vecchia =
          File(p.join(cartella.path, 'planner-20200101-120000.sqlite'));
      final connessione = sqlite.sqlite3.open(vecchia.path);
      connessione.execute(
        'CREATE TABLE events (id TEXT PRIMARY KEY, title TEXT, updated_at INTEGER)',
      );
      connessione.execute(
        "INSERT INTO events (id, title, updated_at) VALUES ('e1', 'Vecchio', 1)",
      );
      connessione.dispose();

      final esito = await verificaCopia(vecchia);

      expect(esito.ok, isTrue);
      expect(esito.conteggi['events'], 1);
      expect(esito.conteggi.containsKey('categories'), isFalse);
    });
  });

  group('manutenzione', () {
    test('la rotazione tiene le N copie piu\' recenti e lascia le emergenze',
        () async {
      final nomi = <String>[];
      for (var i = 0; i < 5; i++) {
        quando = quando.add(const Duration(days: 1));
        nomi.add((await copie.snapshot()).name);
      }
      final emergenza = await copie.emergenza();

      final cancellate = await copie.rotazione(3);

      expect(cancellate, [nomi[1], nomi[0]]);
      final rimaste = (await copie.elenco()).map((c) => c.name).toSet();
      expect(rimaste, {nomi[4], nomi[3], nomi[2], emergenza.name});
      // Anche il foglio se ne va con la sua copia: un foglio orfano resterebbe
      // li' per sempre.
      expect(
        File(p.join(cartella.path, BackupNaming.foglioDi(nomi[0])))
            .existsSync(),
        isFalse,
      );
    });

    test('la copia prima dell\'aggiornamento resta fuori dalla rotazione',
        () async {
      final preAggiornamento = await copie.snapshot(
        motivo: BackupReason.preAggiornamento,
      );
      for (var i = 0; i < 5; i++) {
        quando = quando.add(const Duration(days: 1));
        await copie.snapshot();
      }

      final cancellate = await copie.rotazione(3);

      expect(cancellate, hasLength(2));
      expect(cancellate, isNot(contains(preAggiornamento.name)));
      final rimaste = (await copie.elenco()).map((c) => c.name).toSet();
      expect(rimaste, contains(preAggiornamento.name));
      expect(rimaste, hasLength(4), reason: '3 recenti + quella protetta');
    });

    test('le dimensioni raccontano database, WAL e appoggio', () async {
      evento('e1');
      final prima = db.dimensioni();
      expect(prima.database, greaterThan(0));

      db.checkpoint();

      // Con il WAL portato dentro il file principale, il file di appoggio si
      // svuota: e' quello che rende sicura la copia fatta **da fuori** (l'auto
      // backup di Android legge i file).
      expect(db.dimensioni().wal, 0);
      expect(await copie.dimensione(), 0, reason: 'nessuna copia ancora');
      await copie.snapshot();
      expect(await copie.dimensione(), greaterThan(0));
    });

    test('ultimo cambio: nessun dato, poi la data della riga piu\' recente',
        () {
      expect(db.ultimoCambio(), isNull);

      evento('e1', updatedAt: 5000);
      evento('e2', updatedAt: 9000);

      expect(db.ultimoCambio(), DateTime.fromMillisecondsSinceEpoch(9000));
    });

    test('il database vivo si dichiara integro', () {
      evento('e1');
      // E' lo stesso comando del pulsante «Verifica integrità».
      expect(db.integrita(), 'ok');
    });
  });
}
