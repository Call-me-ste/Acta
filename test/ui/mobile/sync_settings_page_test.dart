import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/sync/sync_auth.dart';
import 'package:planner/core/sync/sync_gateway.dart';
import 'package:planner/core/sync/drive_failure.dart';
import 'package:planner/core/sync/sync_service.dart';
import 'package:planner/core/sync/unconfigured_sync_auth.dart';
import 'package:planner/features/sync/sync_controller.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/ui/mobile/sync_settings_page.dart';

void main() {
  late DatabaseService database;
  late SyncController controller;

  setUp(() async {
    database = DatabaseService();
    await database.init(dbPath: ':memory:');
  });

  tearDown(() => database.close());

  Future<void> apri(
    WidgetTester tester,
    SyncAuthService auth, {
    double scala = 1,
    SyncGateway Function()? gateway,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    if (scala != 1) tester.platformDispatcher.textScaleFactorTestValue = scala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    controller = SyncController(
      auth: auth,
      sync: SyncService(database),
      createGateway: gateway ?? () => throw StateError('Gateway di prova'),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SyncController>.value(
        value: controller,
        child: const MaterialApp(home: SyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> apriOpzioniAvanzate(WidgetTester tester) async {
    final riga = find.text('Opzioni avanzate');
    await tester.ensureVisible(riga);
    await tester.tap(riga);
    await tester.pumpAndSettle();
  }

  testWidgets('sync non configurato: messaggio semplice e nessun menu tecnico',
      (tester) async {
    await apri(tester, const UnconfiguredSyncAuthService());

    expect(
      find.text(
        'La sincronizzazione non è ancora disponibile. I dati restano su '
        'questo telefono.',
      ),
      findsOneWidget,
    );
    expect(find.text('Non disponibile'), findsOneWidget);
    expect(find.textContaining('client OAuth'), findsNothing);
    expect(
      find.textContaining('I dati restano nello spazio privato del tuo Drive'),
      findsOneWidget,
    );

    expect(find.text('Opzioni avanzate'), findsNothing);
  });

  testWidgets('account collegato: stato, azione principale e uscita avanzata',
      (tester) async {
    final auth = _Auth(signedIn: true);
    await apri(tester, auth);

    expect(find.text('Account collegato: planner@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-ora')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('sync-ora'))).height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
    expect(find.text('Scollega account Google'), findsNothing);

    await apriOpzioniAvanzate(tester);
    expect(find.byKey(const ValueKey('sync-scollega')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('sync-scollega'))).height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
    await tester.tap(find.byKey(const ValueKey('sync-scollega')));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isFalse);
    expect(find.text('Collega Google Drive'), findsOneWidget);
  });

  testWidgets('Drive pieno offre un’azione senza dettagli tecnici',
      (tester) async {
    await apri(tester, _Auth(signedIn: true),
        scala: 2,
        gateway: () => throw const DriveFailure(DriveFailureKind.storageFull));
    await controller.connect();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sync-errore')), findsOneWidget);
    expect(find.textContaining('Google Drive è pieno'), findsOneWidget);
    expect(find.text('Gestisci spazio'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
    expect(find.textContaining('Nessun gateway di sync configurato'),
        findsNothing);

    expect(find.textContaining('DriveFailure'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a testo ingrandito non trabocca e i bersagli sono almeno 48 dp',
      (tester) async {
    await apri(tester, const UnconfiguredSyncAuthService(), scala: 1.3);

    expect(tester.takeException(), isNull);
    for (final chiave in ['sync-collega']) {
      expect(
        tester.getSize(find.byKey(ValueKey(chiave))).height,
        greaterThanOrEqualTo(AppSpacing.touchTarget),
        reason: '$chiave è più piccolo del bersaglio minimo',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('un ripristino impedisce un nuovo sync finché è in corso',
      (tester) async {
    var attempts = 0;
    await apri(tester, _Auth(signedIn: true), gateway: () {
      attempts++;
      throw const DriveFailure(DriveFailureKind.temporary);
    });
    await controller.whileRestoring(() async {
      await controller.connect();
      expect(attempts, 0);
    });
    await controller.connect();
    expect(attempts, 1);
  });
}

class _Auth implements SyncAuthService {
  _Auth({required this.signedIn});

  bool signedIn;

  final _account = const SyncAccount(email: 'planner@example.com');

  @override
  bool get isSupported => true;

  @override
  bool get isSignedIn => signedIn;

  @override
  SyncAccount? get account => signedIn ? _account : null;

  @override
  Future<SyncAccount> signIn() async {
    signedIn = true;
    return _account;
  }

  @override
  Future<void> signOut() async => signedIn = false;

  @override
  Future<String> accessToken() async => 'test-token';
}
