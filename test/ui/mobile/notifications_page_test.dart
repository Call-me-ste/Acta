import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notifications/notification_settings_controller.dart';
import 'package:planner/features/notifications/notification_sink.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/ui/mobile/notifications_body.dart';
import 'package:planner/ui/mobile/notifications_prova.dart';
import 'package:planner/ui/mobile/settings_page.dart';

import '../../support/fake_notification_sink.dart';

void main() {
  late DatabaseService db;
  late AppSettingsController impostazioni;
  late NotificationSettingsController notifiche;
  late PaletteController palette;
  late FakeNotificationSink sink;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    impostazioni = AppSettingsController(db.settings)..load();
    notifiche = NotificationSettingsController(db.settings)..load();
    sink = FakeNotificationSink();
    palette = PaletteController(db)
      ..load()
      ..allineaPresets();
  });

  tearDown(() => db.close());

  Future<void> apri(
    WidgetTester tester, {
    Widget? pagina,
    double scala = 1,
  }) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    if (scala != 1) tester.platformDispatcher.textScaleFactorTestValue = scala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: impostazioni),
          ChangeNotifierProvider.value(value: notifiche),
          Provider<NotificationSink>.value(value: sink),
          // La pagina intera ne vuole altri (la riga del colore, i comandi dei
          // dati di prova): qui si prova **la sezione**, quindi bastano finti
          // di quelli che la pagina costruisce attorno a lei.
          ChangeNotifierProvider.value(value: palette),
          ChangeNotifierProvider.value(value: CategoryController(db)),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
          Provider<DatabaseService>.value(value: db),
        ],
        child: MaterialApp(
          home: pagina ??
              Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [NotificationsBody()],
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> apriDettaglio(WidgetTester tester, String chiave) async {
    final riga = find.byKey(ValueKey(chiave));
    await tester.ensureVisible(riga);
    await tester.tap(riga);
    await tester.pumpAndSettle();
  }

  testWidgets('la pagina mostra quando arrivano gli avvisi', (tester) async {
    notifiche.setAttive(true);
    await apri(tester);

    expect(find.text('Avvisi'), findsOneWidget);
    expect(find.text('Eventi'), findsOneWidget);
    expect(find.text('To do'), findsOneWidget);
    expect(find.text('Riepilogo serale'), findsOneWidget);
    expect(find.text('Disattivato'), findsOneWidget);
    expect(find.text('Stile degli avvisi'), findsOneWidget);
    expect(find.textContaining('senza orario alle 09:00'), findsOneWidget);
    expect(find.textContaining('15 minuti prima'), findsOneWidget);
    expect(find.text('Opzioni avanzate'), findsNothing);
    expect(find.text('Ore silenziose'), findsNothing);
  });

  testWidgets('gli anticipi e gli orari si trovano nel dettaglio giusto',
      (tester) async {
    notifiche.setAttive(true);
    await apri(tester);

    await apriDettaglio(tester, 'notifica-evento');
    expect(find.byKey(const ValueKey('notifica-ora-tutto-il-giorno')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('notifica-ora-todo')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('notifica-anticipo-evento')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 minuti prima'));
    await tester.pumpAndSettle();
    expect(notifiche.anticipoEventi, 30);
    expect(notifiche.anticipoTodo, 0);

    Navigator.of(tester
            .element(find.byKey(const ValueKey('notifica-anticipo-evento'))))
        .pop();
    await tester.pumpAndSettle();
    await apriDettaglio(tester, 'notifica-todo');
    expect(find.byKey(const ValueKey('notifica-ora-todo')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('notifica-anticipo-todo')), findsOneWidget);
  });
  testWidgets('a interruttore spento non ci sono righe da configurare',
      (tester) async {
    await apri(tester);

    expect(find.byKey(const ValueKey('notifica-attive')), findsOneWidget);
    expect(find.text('Disattivati'), findsOneWidget);
    expect(find.byKey(const ValueKey('notifica-evento')), findsNothing);
    expect(find.byKey(const ValueKey('notifica-silenzio')), findsNothing);
  });

  testWidgets('a testo ingrandito non trabocca e i bersagli sono almeno 48 dp',
      (tester) async {
    notifiche.setAttive(true);
    await apri(tester, scala: 1.3);

    expect(tester.takeException(), isNull);
    for (final chiave in [
      'notifica-attive',
      'notifica-evento',
      'notifica-todo',
      'notifica-riepilogo',
      'notifica-come-suonano',
    ]) {
      expect(
        tester.getSize(find.byKey(ValueKey(chiave))).height,
        greaterThanOrEqualTo(AppSpacing.touchTarget),
        reason: '$chiave è più piccolo del bersaglio minimo',
      );
    }

    await apriDettaglio(tester, 'notifica-todo');
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('notifica-ora-todo'))).height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
  });

  testWidgets('l\'interruttore generale accende e **scrive**', (tester) async {
    await apri(tester);

    await tester.tap(find.byKey(const ValueKey('notifica-attive')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(notifiche.attive, isTrue);
    // E le righe compaiono subito: non c'è niente da ricaricare.
    expect(find.byKey(const ValueKey('notifica-evento')), findsOneWidget);

    // La scrittura su disco è una **microattività** (fuori dal fotogramma del
    // gesto): in un widget test il tempo è finto e si scarica con un `pump` —
    // `pumpEventQueue` qui dentro si incastra, e vale solo nei test puri.
    await tester.pump();
    expect(db.settings.get(NotificationSettingsController.notificheAttiveKey),
        '1');

    // La scelta sopravvive a un riavvio: si rilegge da disco, come all'avvio.
    final rilette = NotificationSettingsController(db.settings)..load();
    expect(rilette.attive, isTrue);
    expect(rilette.riepilogo, isFalse);
  });

  testWidgets('spegnere un tipo lo scrive, e solo quello', (tester) async {
    notifiche.setAttive(true);
    await apri(tester);

    await apriDettaglio(tester, 'notifica-riepilogo');
    await tester.tap(find.byKey(const ValueKey('notifica-riepilogo-attivo')));
    await tester.pumpAndSettle();
    expect(notifiche.riepilogo, isTrue);
    expect(
        find.byKey(const ValueKey('notifica-ora-riepilogo')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notifica-riepilogo-attivo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(notifiche.riepilogo, isFalse);
    await tester.pump();
    expect(db.settings.get(NotificationSettingsController.riepilogoKey), '0');
    expect(
      db.settings.get(NotificationSettingsController.todoKey),
      isNull,
      reason: 'gli altri tipi non si toccano',
    );
  });

  testWidgets('dalle Impostazioni la riga «Notifiche» apre la pagina',
      (tester) async {
    await apri(tester, pagina: const SettingsPage());

    // La pagina è un elenco pigro: la riga sta in mezzo e va portata in vista.
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    final riga = find.byKey(const ValueKey('impostazioni-notifiche'));
    expect(riga, findsOneWidget);
    expect(find.byKey(const ValueKey('notifica-attive')), findsNothing,
        reason: 'le manopole non stanno più in mezzo alle altre impostazioni');

    await tester.tap(riga);
    await tester.pumpAndSettle();
    expect(find.text('Notifiche'), findsWidgets);
    expect(find.byKey(const ValueKey('notifica-attive')), findsOneWidget,
        reason: 'la riga apre la pagina, che porta il corpo con le manopole');
    expect(find.text('Opzioni avanzate'), findsNothing);
  });

  testWidgets('permesso negato: l\'interruttore resta spento e la riga lo dice',
      (tester) async {
    sink.permesso = false;
    await apri(tester);

    await tester.tap(find.byKey(const ValueKey('notifica-attive')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(sink.richiesteDiPermesso, 1,
        reason: 'il permesso si chiede accendendo, non all\'avvio');
    expect(notifiche.attive, isFalse,
        reason:
            'senza permesso l\'interruttore non sale: accenderlo e non far\n'
            'arrivare niente sarebbe una bugia');
    expect(find.byKey(const ValueKey('notifica-permesso')), findsOneWidget);
    expect(find.text('Android non lascia arrivare gli avvisi'), findsOneWidget);
  });

  testWidgets('la scorciatoia al permesso apre le impostazioni di Android',
      (tester) async {
    sink.permesso = false;
    await apri(tester);
    await tester.tap(find.byKey(const ValueKey('notifica-attive')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('notifica-permesso')));
    await tester.pumpAndSettle();

    expect(sink.impostazioniAperte, isTrue,
        reason:
            'dal secondo diniego Android non chiede più: resta solo la strada delle impostazioni');
  });

  testWidgets(
      'la puntualità si aggiorna tornando dalle impostazioni di Android',
      (tester) async {
    sink.esatto = false;
    notifiche.setAttive(true);
    await apri(tester);
    expect(find.byKey(const ValueKey('notifica-esattezza')), findsOneWidget);

    sink.esatto = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notifica-esattezza')), findsNothing);
  });

  testWidgets('lo stile offre i controlli di Acta e il collegamento ad Android',
      (tester) async {
    notifiche.setAttive(true);
    await apri(tester);
    await apriDettaglio(tester, 'notifica-come-suonano');

    expect(find.byKey(const ValueKey('notifica-suono')), findsOneWidget);
    expect(find.text('Ore silenziose'), findsOneWidget);
    await apriDettaglio(tester, 'notifica-sistema');
    expect(sink.impostazioniAperte, isTrue);
  });
  testWidgets('la prova pianifica **un** avviso, fra un minuto',
      (tester) async {
    notifiche.setAttive(true);
    await apri(tester);
    expect(sink.avvisi, isEmpty, reason: 'prima del tocco non c\'è niente');

    final prima = DateTime.now();
    await tester.tap(find.byKey(const ValueKey('notifica-prova')));
    await tester.pumpAndSettle();

    expect(sink.avvisi, hasLength(1),
        reason: 'la prova è **una** notifica, non una pianificazione');
    final prova = sink.avvisi.values.single;
    expect(prova.id, idAvvisoDiProva);
    expect(
      prova.when.difference(prima).inSeconds,
      inInclusiveRange(50, 70),
      reason: 'l\'avviso di prova arriva fra un minuto',
    );
    expect(
        find.widgetWithText(SnackBar, 'Arriva fra un minuto'), findsOneWidget,
        reason: 'chi tocca deve sapere quando aspettarsi l\'avviso');

    // Toccare due volte **sostituisce** quello di prima: non si accumulano.
    await tester.tap(find.byKey(const ValueKey('notifica-prova')));
    await tester.pumpAndSettle();
    expect(sink.avvisi, hasLength(1));
  });
}
