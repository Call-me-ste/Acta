import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_files.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/backup/backup_controller.dart';
import 'package:planner/features/backup/backup_service.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/ui/shared/backup_guard.dart';

/// Le due cose che `BackupGuard` fa e che **non si vedono a occhio**: la copia
/// che parte dopo il primo fotogramma e il WAL che rientra nel file principale
/// quando l'app va in secondo piano.
///
/// Sono esattamente le due che, se smettessero di funzionare, non se ne
/// accorgerebbe nessuno fino al giorno in cui servono — cioe' quello in cui si
/// perdono i dati.
void main() {
  late Directory radice;
  late DatabaseService db;
  late BackupController copie;

  // Una spia per la **chiamata**: il widget deve far partire `autoSeDovuta` dopo
  // il primo fotogramma, e quello si vede contando. Cosa faccia poi quella
  // chiamata lo provano i test del controller (con I/O vero, in un test
  // normale): dentro un widget test l'attesa dei file passa dal tempo finto, e
  // mischiare le due cose rende il test instabile invece che severo.
  late _Spia spia;

  setUp(() async {
    radice = Directory.systemTemp.createTempSync('planner-guard');
    db = DatabaseService();
    await db.init(dbPath: p.join(radice.path, 'planner.db'));
    spia = _Spia(
      db,
      AppSettingsController(db.settings)..load(),
      servizio: BackupService(
        db,
        cartella: Directory(p.join(radice.path, 'copie')),
        dispositivo: () => 'test',
      ),
    );
    copie = spia;
  });

  tearDown(() {
    db.close();
    if (radice.existsSync()) radice.deleteSync(recursive: true);
  });

  Future<void> monta(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BackupController>.value(value: copie),
          Provider<DatabaseService>.value(value: db),
        ],
        child: const MaterialApp(home: BackupGuard(child: SizedBox())),
      ),
    );
  }

  void evento(String id) {
    db.insertEvent({
      'id': id,
      'title': 'Da salvare',
      'start_time': 1000,
      'end_time': 2000,
    });
  }

  testWidgets('la copia automatica parte da sola, dopo il primo fotogramma',
      (tester) async {
    evento('e1');

    await monta(tester);
    await tester.pump();

    expect(
      spia.chiamate,
      1,
      reason: 'il gancio dell\'avvio deve far partire la copia automatica una '
          'volta sola',
    );

    // E non una seconda volta a ogni fotogramma: il gancio e' un callback di
    // fine fotogramma **una tantum**, non un ciclo.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(spia.chiamate, 1);
  });

  testWidgets('all\'avvio la coda si compatta da sola', (tester) async {
    evento('e1');
    // Cinque scritture sullo stesso elemento: quattro sono giro intermedio.
    for (var i = 1; i <= 5; i++) {
      db.outbox.enqueue(
        operationId: 'op$i',
        entity: 'todo',
        entityId: 't1',
        operation: 'upsert',
        version: i,
        updatedAt: i,
        payload: const {'id': 't1'},
      );
    }
    expect(db.outbox.pendingCount(), 5);

    await monta(tester);
    await tester.pump();

    // La compattazione automatica e' sincrona: e' gia' passata quando il
    // fotogramma finisce (la copia, invece, e' asincrona e la spia la conta).
    expect(db.outbox.pendingCount(), 1);
    expect(db.meta.get('lastCompactAt'), isNotNull);
  });

  testWidgets('in pausa il WAL rientra nel file principale', (tester) async {
    evento('e1');
    await monta(tester);
    // Con WAL attivo le ultime scritture stanno nel file di appoggio: se
    // restassero li', la copia che Android fa **dei file** sarebbe piu' vecchia
    // dell'ultima modifica.
    expect(db.dimensioni().wal, greaterThan(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    expect(db.dimensioni().wal, 0);
  });
}

/// Il controller con un contatore sulle chiamate: serve a provare **cosa fa il
/// widget** (far partire la copia, una volta sola), non cosa fa la copia —
/// quella la provano i test del controller, con l'I/O vero.
class _Spia extends BackupController {
  _Spia(super.database, super.settings, {required super.servizio});

  int chiamate = 0;

  @override
  Future<void> autoSeDovuta() async {
    chiamate++;
    await super.autoSeDovuta();
  }
}
