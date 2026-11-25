import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/dev_flags.dart';
import 'package:planner/features/backup/backup_controller.dart';
import 'package:planner/features/backup/backup_service.dart';
import 'package:planner/features/backup/domain/backup_file.dart';
import 'package:planner/features/settings/app_settings_controller.dart';

/// Le **decisioni** sulle copie: quando farne una, quando no, cosa succede se
/// non riesce.
///
/// Sono le regole che, sbagliate, si vedono dopo mesi: una cartella piena di
/// copie identiche (regola troppo larga), o nessuna copia perche' "l'ultima e'
/// di ieri" (regola troppo stretta). Con l'orologio vero non si proverebbero.
void main() {
  late Directory radice;
  late Directory cartella;
  late DatabaseService db;
  late AppSettingsController impostazioni;
  late BackupController controller;

  /// Orologio finto: si sposta a mano per far passare i giorni.
  var quando = DateTime(2026, 9, 23, 20, 0, 0);

  setUp(() async {
    radice = Directory.systemTemp.createTempSync('planner-controller');
    cartella = Directory(p.join(radice.path, 'copie'));
    quando = DateTime(2026, 9, 23, 20, 0, 0);

    db = DatabaseService();
    await db.init(dbPath: p.join(radice.path, 'planner.db'));
    impostazioni = AppSettingsController(db.settings)..load();

    controller = BackupController(
      db,
      impostazioni,
      servizio: BackupService(
        db,
        cartella: cartella,
        adesso: () => quando,
        dispositivo: () => 'test',
      ),
      adesso: () => quando,
    );
  });

  tearDown(() {
    db.close();
    if (radice.existsSync()) radice.deleteSync(recursive: true);
  });

  void evento(String id, {String titolo = 'Evento'}) {
    db.insertEvent({
      'id': id,
      'title': titolo,
      'start_time': 1000,
      'end_time': 2000,
      // La marca si scrive a mano: con `DateTime.now()` il test dipenderebbe
      // dall'ora vera, che non e' quella dell'orologio finto.
      'updated_at': quando.millisecondsSinceEpoch,
    });
  }

  List<BackupFile> normali() =>
      controller.copie.where((c) => !c.eEmergenza).toList();

  test('su un database senza dati non si copia niente', () async {
    await controller.autoSeDovuta();

    expect(controller.copie, isEmpty);
    expect(impostazioni.lastBackupAt, isNull);
  });

  // ─── Il cambio di build ─────────────────────────────────
  //
  // I dati passano da una build all'altra con `adb install -r`: stesso
  // pacchetto, quindi la copia si fa **qui**, al primo avvio dopo il cambio.

  /// L'**altra** build. Il test non dà per scontato quale sia questa: la suite
  /// gira sia senza define (`ufficiale`) sia con `--dart-define=dev=true`.
  String altraBuild() => buildKind == 'test' ? 'ufficiale' : 'test';

  test('dati scritti da un\'altra build: si copia prima di aprirli', () async {
    evento('e1');
    impostazioni.setBuildKind(altraBuild());

    await controller.autoSeDovuta();

    expect(normali(), hasLength(1));
    expect(normali().single.reason, BackupReason.preCambioBuild);
    expect(impostazioni.buildKind, buildKind);
  });

  test('stessa build: la copia precambio non ci sta', () async {
    evento('e1');
    impostazioni.setBuildKind(buildKind);

    await controller.autoSeDovuta();

    expect(normali(), hasLength(1));
    expect(normali().single.reason, BackupReason.automatica);
  });

  test('installazione nuova: si scrive la chiave, non si copia', () async {
    evento('e1');
    expect(impostazioni.buildKind, isNull);

    await controller.autoSeDovuta();

    expect(impostazioni.buildKind, buildKind);
    expect(
      normali().single.reason,
      BackupReason.automatica,
      reason: 'chiave assente = non c\'è niente di un\'altra build da salvare',
    );
  });

  test('una copia precambio che fallisce non dimentica il cambio', () async {
    evento('e1');
    impostazioni.setBuildKind(altraBuild());
    controller = BackupController(
      db,
      impostazioni,
      servizio: _ServizioRotto(
        db,
        cartella: cartella,
        adesso: () => quando,
        dispositivo: () => 'test',
      ),
      adesso: () => quando,
    );

    await controller.autoSeDovuta();

    expect(controller.errore, isNotNull);
    expect(
      impostazioni.buildKind,
      altraBuild(),
      reason: 'si riprova al prossimo avvio, non si perde il cambio',
    );
  });

  test('la prima copia automatica arriva con qualcosa da salvare', () async {
    evento('e1');

    await controller.autoSeDovuta();

    expect(normali(), hasLength(1));
    expect(normali().single.reason, BackupReason.automatica);
    expect(impostazioni.lastBackupAt, quando);

    // Secondo avvio lo stesso giorno: non si copia di nuovo.
    await controller.autoSeDovuta();
    expect(normali(), hasLength(1));
  });

  test(
      'l\'ultima copia e\' quella vera del file, non una data rimasta indietro',
      () async {
    evento('e1');
    await controller.servizio.snapshot(motivo: BackupReason.preAggiornamento);
    impostazioni.markBackupDone(quando.subtract(const Duration(days: 1)));
    await controller.carica();

    expect(controller.ultimaCopia, quando);
  });

  test('il giorno dopo, senza cambiamenti, non si copia', () async {
    evento('e1');
    await controller.autoSeDovuta();

    quando = quando.add(const Duration(hours: 24));
    await controller.autoSeDovuta();

    expect(normali(), hasLength(1), reason: 'niente di nuovo da fotografare');
  });

  test('il giorno dopo, con un cambiamento, si copia', () async {
    evento('e1');
    await controller.autoSeDovuta();

    quando = quando.add(const Duration(hours: 24));
    evento('e2');
    await controller.autoSeDovuta();

    expect(normali(), hasLength(2));
    expect(normali().first.reason, BackupReason.automatica);
  });

  test('la copia a richiesta non aspetta il giorno dopo', () async {
    evento('e1');
    await controller.autoSeDovuta();

    await controller.adesso();

    expect(normali(), hasLength(2));
    expect(normali().first.reason, BackupReason.manuale);
    expect(controller.errore, isNull);
  });

  test('la rotazione tiene la retention e non tocca il posto di emergenza',
      () async {
    impostazioni.setBackupRetention(3);
    evento('e1');
    await controller.autoSeDovuta();
    expect(controller.copie.where((c) => c.eEmergenza), hasLength(1));

    for (var i = 0; i < 5; i++) {
      quando = quando.add(const Duration(days: 1));
      evento('dopo-$i');
      await controller.adesso();
    }

    expect(normali(), hasLength(3));
    expect(
      controller.copie.where((c) => c.eEmergenza),
      hasLength(1),
      reason: 'le emergenze stanno fuori dalla rotazione',
    );
  });

  test('un guaio non fa cadere niente: finisce nella riga da mostrare',
      () async {
    evento('e1');
    // La cartella delle copie diventa un **file**: la copia non puo' riuscire.
    cartella.createSync(recursive: true);
    cartella.deleteSync(recursive: true);
    File(cartella.path).writeAsStringSync('non sono una cartella');

    await controller.adesso();

    expect(controller.errore, isNotNull);
    expect(controller.occupato, isFalse);
    // E il database e' ancora li': una copia fallita non tocca i dati.
    expect(db.getEvents().single['title'], 'Evento');
  });

  test('la verifica dice cosa contiene la copia, e cosa non va', () async {
    evento('e1');
    db.insertTodo({'id': 't1', 'title': 'Todo'});
    final copia = await controller.servizio.snapshot();

    final buona = await controller.verifica(copia);
    expect(buona, contains('Integra'));
    expect(buona, contains('events'));

    File(p.join(cartella.path, copia.name)).writeAsBytesSync([1, 2, 3]);
    final rotta = await controller.verifica(copia);
    expect(rotta, contains('Danneggiata'));
  });

  test('il ripristino rimette i dati e lascia la copia di sicurezza', () async {
    evento('e1', titolo: 'Prima');
    final copia = await controller.servizio.snapshot();
    evento('e2', titolo: 'Dopo');

    await controller.ripristina(copia);

    expect(db.getEvents().map((r) => r['title']), ['Prima']);
    expect(controller.errore, isNull);
    // La copia di sicurezza di quello che c'era **prima** del ripristino, piu'
    // quella scelta: due copie nella cartella.
    expect(controller.copie, hasLength(2));
    expect(
      controller.copie.map((c) => c.reason),
      contains(BackupReason.preRipristino),
    );
  });
}

/// Il servizio che la copia **non** la sa fare: serve a provare la strada del
/// guaio (la cartella delle copie diventa un file solo per lo snapshot, cosi'
/// anche la lettura dell'elenco resterebbe in piedi).
class _ServizioRotto extends BackupService {
  _ServizioRotto(
    super.database, {
    required super.cartella,
    required super.adesso,
    required super.dispositivo,
  });

  @override
  Future<BackupFile> snapshot({
    BackupReason motivo = BackupReason.automatica,
  }) async =>
      throw BackupFallito('cartella piena');
}
