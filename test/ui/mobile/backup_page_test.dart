import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/backup/backup_controller.dart';
import 'package:planner/features/backup/backup_service.dart';
import 'package:planner/features/backup/domain/backup_file.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_filter_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/ui/mobile/backup_extras.dart';
import 'package:planner/ui/mobile/backup_page.dart';
import 'package:planner/ui/mobile/recovery_input.dart';
import 'package:planner/ui/mobile/settings_page.dart';

import '../../support/theme_providers.dart';

/// La pagina **Dati e backup**: azioni quotidiane visibili, strumenti avanzati
/// in un pannello locale chiuso all'apertura.
///
/// Qui si prova la **pagina** — cosa si vede, cosa dicono i comandi, cosa fa la
/// conferma del ripristino — con un servizio delle copie finto: i file veri li
/// provano i test del servizio e del controller, in un test normale. Dentro un
/// widget test l'attesa dell'I/O vero non completa (il tempo è finto), quindi
/// mischiare le due cose non rende il test più severo: lo rende appeso.
void main() {
  late Directory radice;
  late DatabaseService db;
  late _ServizioFinto servizio;
  late AppSettingsController impostazioni;
  late BackupController copie;
  late List<String> condivisi;

  setUp(() async {
    radice = Directory.systemTemp.createTempSync('planner-pagina-copie');
    condivisi = [];
    db = DatabaseService();
    await db.init(dbPath: p.join(radice.path, 'planner.db'));
    servizio = _ServizioFinto(
      db,
      cartella: Directory(p.join(radice.path, 'copie')),
    );
    impostazioni = AppSettingsController(db.settings)..load();
    copie = BackupController(db, impostazioni, servizio: servizio);
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
    });
  }

  Future<void> apri(
    WidgetTester tester, {
    double scala = 1,
    Size dimensioni = const Size(360, 800),
  }) async {
    tester.view.physicalSize = dimensioni;
    tester.view.devicePixelRatio = 1;
    if (scala != 1) tester.platformDispatcher.textScaleFactorTestValue = scala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsController>.value(
            value: impostazioni,
          ),
          ChangeNotifierProvider<BackupController>.value(value: copie),
          Provider<DatabaseService>.value(value: db),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
          ChangeNotifierProvider(create: (_) => CategoryController(db)),
          ChangeNotifierProvider(create: (_) => PaletteController(db)..load()),
          ChangeNotifierProvider(
            create: (_) => TodoFilterController(db.settings)..load(),
          ),
        ],
        child: MaterialApp(
          home: BackupPage(
            condividi: (percorso) async => condivisi.add(percorso),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> apriOpzioniAvanzate(WidgetTester tester) async {
    final riga = find.text('Opzioni avanzate');
    await tester.ensureVisible(riga);
    await tester.pumpAndSettle();
    await tester.tap(riga);
    await tester.pumpAndSettle();
  }

  group('vista semplice', () {
    testWidgets('mostra le tre cose che servono, e non i comandi',
        (tester) async {
      evento('e1');
      await copie.adesso();
      await apri(tester);

      // Quello che serve: sapere che le copie ci sono, mandarne una fuori,
      // rimetterne dentro una, sapere cosa fare prima di disinstallare.
      expect(find.byKey(const ValueKey('stato-copie')), findsOneWidget);
      expect(find.textContaining('L\'ultima è di'), findsOneWidget);
      expect(find.byKey(const ValueKey('esporta-copia')), findsOneWidget);
      expect(find.text('Ripristina una copia'), findsOneWidget);
      expect(find.textContaining('Prima di disinstallare'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('backup-opzioni-avanzate')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('copia-adesso')), findsNothing);
      for (final chiave in [
        'esporta-copia',
        'backup-opzioni-avanzate',
        'copia-${servizio.creati.single.name}',
      ]) {
        expect(
          tester.getSize(find.byKey(ValueKey(chiave))).height,
          greaterThanOrEqualTo(AppSpacing.touchTarget),
          reason: '$chiave è più piccolo del bersaglio minimo',
        );
      }

      // I dettagli tecnici restano nel pannello chiuso.
      expect(find.byKey(const ValueKey('verifica-database')), findsNothing);
      expect(find.byKey(const ValueKey('compatta-adesso')), findsNothing);
      expect(find.byKey(const ValueKey('copie-da-tenere')), findsNothing);
      expect(find.textContaining('Database:'), findsNothing);
      expect(find.textContaining('schema dati'), findsNothing);
      expect(find.textContaining('/copie'), findsNothing);
    });

    testWidgets('elenca solo le tre copie più recenti', (tester) async {
      evento('e1');
      for (var i = 0; i < 5; i++) {
        await copie.adesso();
      }
      await apri(tester);

      expect(servizio.creati, hasLength(5));
      final mostrate = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('copia-planner'),
      );
      expect(mostrate, findsNWidgets(3));
    });

    testWidgets('"Fai il backup adesso" fa una copia e lo dice',
        (tester) async {
      evento('e1');
      await apri(tester);
      await apriOpzioniAvanzate(tester);

      final copia = find.byKey(const ValueKey('copia-adesso'));
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(copia);
      await tester.pumpAndSettle();

      expect(servizio.creati, hasLength(1));
      expect(find.textContaining('Copia fatta'), findsOneWidget);
      expect(
        find.byKey(ValueKey('copia-${servizio.creati.single.name}')),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('"Esporta copia" chiama la condivisione con la copia di adesso',
        (tester) async {
      evento('e1');
      await apri(tester);

      await tester.tap(find.byKey(const ValueKey('esporta-copia')));
      await tester.pumpAndSettle();

      expect(servizio.creati, hasLength(1));
      expect(condivisi, [
        p.join(servizio.cartella.path, servizio.creati.single.name),
      ]);
    });

    testWidgets('il ripristino chiede conferma: con Annulla non tocca niente',
        (tester) async {
      evento('e1');
      await copie.adesso();
      await apri(tester);

      final riga = find.byKey(ValueKey('copia-${servizio.creati.first.name}'));
      await tester.ensureVisible(riga);
      await tester.pumpAndSettle();
      await tester.tap(riga);
      await tester.pumpAndSettle();
      expect(find.text('Ripristinare questa copia?'), findsOneWidget);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(servizio.ripristini, 0);
    });

    testWidgets('il ripristino confermato rimette i dati e lo dice',
        (tester) async {
      evento('e1');
      await copie.adesso();
      evento('e2', titolo: 'Dopo la copia');
      // Il ripristino vero lo prova il servizio: qui basta che la pagina lo
      // **chieda** e racconti cosa è successo (i provider si rileggono).
      servizio.alRipristino = () => db.deleteEvent('e2');
      await apri(tester);

      final riga = find.byKey(ValueKey('copia-${servizio.creati.last.name}'));
      await tester.ensureVisible(riga);
      await tester.pumpAndSettle();
      await tester.tap(riga);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ripristina'));
      await tester.pumpAndSettle();

      expect(servizio.ripristini, 1);
      expect(db.getEvents().map((riga) => riga['title']), ['Evento']);
      expect(find.textContaining('Ripristinata la copia'), findsOneWidget);
    });

    testWidgets('a testo 200% le azioni restano nella vista semplice',
        (tester) async {
      evento('e1');
      await copie.adesso();

      await apri(tester, scala: 2, dimensioni: const Size(320, 640));
      final export = find.byKey(const ValueKey('esporta-copia'));
      final restoreFile = find.byKey(const ValueKey('importa-copia'));
      expect(export.hitTestable(), findsOneWidget);
      await Scrollable.ensureVisible(tester.element(restoreFile),
          alignment: .5);
      await tester.pumpAndSettle();
      expect(restoreFile.hitTestable(), findsOneWidget);

      final recent =
          find.byKey(ValueKey('copia-${servizio.creati.single.name}'));
      await Scrollable.ensureVisible(tester.element(recent), alignment: .5);
      await tester.pumpAndSettle();
      expect(recent.hitTestable(), findsOneWidget);
      await tester.tap(recent);
      await tester.pumpAndSettle();
      expect(find.text('Ripristinare questa copia?'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(servizio.ripristini, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chiave: errore leggibile e un solo invio durante la verifica',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final checked = <String>[];
      final verifying = Completer<void>();
      bool? accepted;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () async {
                accepted = await showRecoveryInput(
                  context,
                  title: 'Apri l’archivio su Drive',
                  action: 'Verifica chiave',
                  submit: (code) async {
                    checked.add(code);
                    if (code == 'errata') {
                      throw const FormatException('Controlla la chiave');
                    }
                    await verifying.future;
                  },
                );
              },
              child: const Text('Recupera'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('Recupera'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      final field = find.byType(TextField);
      final submit = find.text('Verifica chiave');
      await tester.enterText(field, 'errata');
      await tester.pumpAndSettle();
      expect(submit.hitTestable(), findsOneWidget);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Controlla la chiave'), findsOneWidget);
      expect(accepted, isNull);

      await tester.enterText(field, 'corretta');
      await tester.tap(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(checked, ['errata', 'corretta']);
      expect(find.text('Verifica in corso…'), findsOneWidget);
      verifying.complete();
      await tester.pumpAndSettle();
      expect(accepted, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un nome file lungo lascia sempre disponibile Annulla',
        (tester) async {
      await apri(tester, scala: 2, dimensioni: const Size(320, 500));
      final context = tester.element(find.byType(BackupPage));
      final result = chiediConfermaRipristinoDaFile(
        context,
        'Copia Acta ${List.filled(12, 'Archivio personale').join(' ')}.planner',
      );
      await tester.pumpAndSettle();
      expect(find.text('Annulla').hitTestable(), findsOneWidget);
      expect(find.text('Ripristina').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('opzioni avanzate', () {
    testWidgets('mostra gli strumenti e i dettagli tecnici', (tester) async {
      evento('e1');
      await copie.adesso();
      await apri(tester);

      expect(find.byKey(const ValueKey('verifica-database')), findsNothing);
      await apriOpzioniAvanzate(tester);
      expect(find.byKey(const ValueKey('verifica-database')), findsOneWidget);
      expect(find.byKey(const ValueKey('compatta-adesso')), findsOneWidget);
      expect(find.textContaining('Database:'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('copie-da-tenere')),
        200,
      );
      expect(find.byKey(const ValueKey('copie-da-tenere')), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('schema dati'), 200);
      expect(find.textContaining('schema dati'), findsOneWidget);
      expect(find.byKey(const ValueKey('stato-copie')), findsOneWidget);
    });

    testWidgets('"Compatta adesso" dice quanto ha restituito', (tester) async {
      evento('e1');
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
      await apri(tester);
      await apriOpzioniAvanzate(tester);

      final compatta = find.byKey(const ValueKey('compatta-adesso'));
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(compatta);
      await tester.pumpAndSettle();

      expect(db.outbox.pendingCount(), 1,
          reason: 'un\'operazione per elemento');
      expect(find.textContaining('tolte 4 righe in coda'), findsOneWidget);
    });
  });

  testWidgets('la preferenza legacy non apre il pannello avanzato',
      (tester) async {
    evento('e1');
    impostazioni.setAdvancedMode(true);
    await apri(tester);

    expect(impostazioni.advancedMode, isTrue);
    expect(find.byKey(const ValueKey('copia-adesso')), findsNothing);
    expect(find.byKey(const ValueKey('verifica-database')), findsNothing);
    await apriOpzioniAvanzate(tester);

    expect(impostazioni.advancedMode, isTrue);
    expect(db.settings.get('advancedMode'), '1');
    expect(find.byKey(const ValueKey('copia-adesso')), findsOneWidget);
    expect(find.byKey(const ValueKey('verifica-database')), findsOneWidget);
    expect(find.byKey(const ValueKey('stato-copie')), findsOneWidget);
  });

  testWidgets('dalle Impostazioni si arriva alla pagina delle copie',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...themeProviders(db),
          ChangeNotifierProvider<BackupController>.value(value: copie),
          Provider<DatabaseService>.value(value: db),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // La riga sta sotto la piega: la lista e' pigra, quindi prima si scorre — e
    // si porta **in vista**, non solo nell'albero: da quando c'e' anche la
    // sezione delle notifiche la pagina e' piu' lunga, e un widget che esiste ma
    // sta sotto il bordo non riceve il tocco.
    await tester.scrollUntilVisible(find.text('Copie di sicurezza'), 200);
    await tester.ensureVisible(find.text('Copie di sicurezza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copie di sicurezza'));
    await tester.pumpAndSettle();

    expect(find.byType(BackupPage), findsOneWidget);
  });
}

/// Il servizio delle copie **finto**: nella pagina non si provano i file.
class _ServizioFinto extends BackupService {
  _ServizioFinto(super.database, {required super.cartella})
      : super(dispositivo: () => 'test');

  final List<BackupFile> creati = [];
  void Function()? alRipristino;
  int ripristini = 0;

  static DateTime _adesso() => DateTime(2026, 9, 23, 21, 0, 0);

  BackupFile _copia(BackupReason motivo) {
    final quando = _adesso();
    final copia = BackupFile(
      name: BackupNaming.nome(quando, duplicato: creati.length),
      createdAt: quando,
      sizeBytes: 131072,
      sidecar: BackupSidecar(
        appVersion: '1.1.0+2',
        schemaVersion: 1,
        createdAt: quando,
        device: 'test',
        counts: const {'events': 1},
        checksum: 'abcdabcdabcdabcd',
        reason: motivo,
      ),
      verified: true,
    );
    creati.insert(0, copia);
    return copia;
  }

  @override
  Future<BackupFile> snapshot({
    BackupReason motivo = BackupReason.automatica,
  }) async =>
      _copia(motivo);

  @override
  Future<List<BackupFile>> elenco() async => creati;

  @override
  Future<int> dimensione() async => creati.length * 131072;

  @override
  Future<List<String>> rotazione(int retention) async => const [];

  @override
  Future<BackupFile> ripristina(BackupFile copia) async {
    ripristini++;
    alRipristino?.call();
    return _copia(BackupReason.preRipristino);
  }
}
