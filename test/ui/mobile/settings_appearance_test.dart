import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/sync/sync_service.dart';
import 'package:planner/core/sync/unconfigured_sync_auth.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/notifications/notification_settings_controller.dart';
import 'package:planner/features/notifications/notification_sink.dart';

import '../../support/fake_notification_sink.dart';
import 'package:planner/features/palette/domain/palette.dart';
import 'package:planner/features/palette/domain/presets.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/features/sync/sync_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/theme/color_resolver.dart';
import 'package:planner/ui/app_shell.dart';
import 'package:planner/ui/mobile/color_box.dart';
import 'package:planner/ui/mobile/settings_page.dart';
import 'package:planner/ui/mobile/theme_preview.dart';

/// L'aspetto: **due scelte** (chiaro/scuro/sistema e il colore) e il foglio che si
/// apre toccando il colore.
///
/// Perché conta: la recensione dava 5,5/10 a «Impostazioni e colori» («si cambia
/// `surfaceContainerHighest` senza sapere che cos'è»), e l'utente ha chiesto poche
/// scelte in prima pagina, con tutto il resto in una personalizzazione avanzata. La
/// seconda prova che conta è che il tema di tutta l'app **segua** la scelta: era il
/// difetto della v2, dove l'impostazione si salvava e lo schermo restava com'era.
void main() {
  late DatabaseService db;
  late AppSettingsController settings;
  late PaletteController palettes;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    settings = AppSettingsController(db.settings)..load();
    palettes = PaletteController(db)
      ..load()
      ..allineaPresets();
  });

  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    // Lo schermo di prova è più corto di un telefono: il foglio dei colori ha
    // l'anteprima e sei tinte, e sotto la piega non si toccherebbero.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: palettes),
          ChangeNotifierProvider(
            create: (_) => NotificationSettingsController(db.settings)..load(),
          ),
          Provider<NotificationSink>.value(value: FakeNotificationSink()),
          ChangeNotifierProvider(create: (_) => CategoryController(db)),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
          ChangeNotifierProvider(create: (_) => NoteProvider(db)),
          ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
          ChangeNotifierProvider(
            create: (_) => SyncController(
              auth: const UnconfiguredSyncAuthService(),
              sync: SyncService(db),
              createGateway: () => throw StateError('non configurato'),
            ),
          ),
        ],
        child: const AppShell(),
      ),
    );
    await tester.pumpAndSettle();

    // La scheda Impostazioni è l'ultima della barra.
    await tester.tap(find.byKey(const ValueKey('barra-Impostazioni')));
    await tester.pumpAndSettle();
  }

  Palette attiva() => palettes.resolve(settings.activePaletteId);

  Color primaryOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SettingsPage))).colorScheme.primary;

  testWidgets('due scelte: l\'aspetto e il colore, e nessun gergo',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('Aspetto'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
    expect(find.byKey(const ValueKey('aspetto-colore')), findsOneWidget);
    // Il valore dice il colore attivo: il default è «Blu».
    expect(find.text('Blu'), findsOneWidget);
    // Le parole del mestiere non si vedono più, e nemmeno l'elenco dei temi: quello
    // è nella personalizzazione avanzata.
    expect(find.text('Palette'), findsNothing);
    expect(find.text('Preset'), findsNothing);
    expect(find.text('Personalizzata'), findsNothing);
  });

  testWidgets('la riga «Tema e colori»: colore attivo e stessa altezza',
      (tester) async {
    await pumpApp(tester);

    // 1. Si chiama «Tema e colori», col nome del tema attivo sotto.
    expect(find.text('Tema e colori'), findsOneWidget);
    expect(find.text('Blu'), findsOneWidget);

    // 2. Il colore attivo **si vede**: non un'icona qualunque, il colore vero.
    final anteprima = tester.widget<Container>(
      find.byKey(const ValueKey('anteprima-colore')),
    );
    expect(
      (anteprima.decoration! as BoxDecoration).color,
      ColorResolver.hexToColor(attiva().seedHex),
    );

    // 3. E' un bersaglio di sistema (48), e **cresce col testo** come la pillola
    // qui sopra: a scala 1,3 sono 62 px. Il numero esatto della pillola nel test
    // (76) viene dal font dei test, che e' un blocco per glifo: pareggiare quello
    // non direbbe niente su come si vede sul telefono.
    final altezza =
        tester.getSize(find.byKey(const ValueKey('aspetto-colore'))).height;
    expect(altezza, greaterThanOrEqualTo(AppSpacing.touchTarget));

    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('aspetto-colore'))).height,
      greaterThan(altezza),
      reason: 'col testo ingrandito la riga cresce, come la pillola',
    );

    // 4. E si apre il foglio.
    await tester.tap(find.byKey(const ValueKey('aspetto-colore')));
    await tester.pumpAndSettle();
    expect(find.text('Colore principale'), findsOneWidget);
  });

  testWidgets('il foglio minimo: anteprima e una riga di scelta',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('aspetto-colore')));
    await tester.pumpAndSettle();

    // Due righe, nell'ordine: la giornata in miniatura e la scelta. I gruppi
    // doppi («Altri temi») erano la farragine: non ci sono più.
    expect(find.byType(ThemePreview), findsOneWidget);
    expect(find.text('Anteprima'), findsOneWidget);
    expect(find.text('Colore principale'), findsOneWidget);
    expect(find.text('Altri temi'), findsNothing);
    expect(
      find.text('Anteprima').evaluate().single.widget,
      isNotNull,
      reason: 'il titolo della prima riga dice cosa si sta guardando',
    );

    // Gli otto colori curati: una sola riga, e con la casella della ruota sono
    // **nove** caselle in tutto.
    Finder tinte() => find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('tinta-'),
        );
    expect(tinte(), findsNWidgets(presetTutti.length));
    expect(find.byType(ColorBox), findsNWidgets(9));

    // Ogni casella mostra **tutti** i colori degli elementi: erano tre pallini
    // su otto, ed era la parte «incompleta» della segnalazione. Il conteggio
    // è per casella: la riga «Tema e colori» dietro il foglio ha la sua
    // striscia, ma non è una casella di scelta.
    expect(
      find.descendant(
        of: find.byType(ColorBox),
        matching: find.byType(ColorStrip),
      ),
      findsNWidgets(8),
    );

    // E in fondo alla prima riga la casella che apre la ruota.
    expect(find.byKey(const ValueKey('altro-colore')), findsOneWidget);
    expect(find.text('Il mio colore'), findsOneWidget);

    // Niente codici: si sceglie guardando e leggendo i nomi.
    expect(find.textContaining('#'), findsNothing);
    expect(find.text('Rosso'), findsOneWidget);
  });

  testWidgets('una tinta pronta cambia il tema **e** i colori degli elementi',
      (tester) async {
    await pumpApp(tester);
    final prima = primaryOf(tester);
    final coloriPrima = List<String>.of(attiva().colors);

    await tester.tap(find.byKey(const ValueKey('aspetto-colore')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tinta-colore-rosa')));
    await tester.pumpAndSettle();
    expect(settings.activePaletteId, 'colore-rosa');
    expect(primaryOf(tester), isNot(prima), reason: 'il tema segue la scelta');
    expect(
      attiva().colors,
      isNot(coloriPrima),
      reason: 'una tinta pronta porta con sé anche i colori degli elementi',
    );
    expect(db.settings.get('activePaletteId'), 'colore-rosa');
  });

  testWidgets('la ruota scrive sul tema tuo, e il tema tuo resta uno solo',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('aspetto-colore')));
    await tester.pumpAndSettle();
    // Il foglio è scorrevole: la casella sta in fondo alla prima riga, e su uno
    // schermo corto va portata in vista — come farebbe un dito.
    final altro = find.byKey(const ValueKey('altro-colore'));
    await tester.ensureVisible(altro);
    await tester.pumpAndSettle();
    await tester.tap(altro);
    await tester.pumpAndSettle();

    // Niente campo da scrivere: si sceglie dalla ruota o dai colori pronti che
    // ha dentro.
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pronto-#4db6ac')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usa questo'));
    await tester.pumpAndSettle();

    final nuova = attiva();
    expect(nuova.isPreset, isFalse);
    expect(nuova.id, PaletteController.myColorId);
    expect(nuova.name, PaletteController.myColorName);
    expect(nuova.seedHex, '#4db6ac');
    expect(
      nuova.colors,
      famigliaVicina('#4db6ac'),
      reason: 'il colore scelto porta con sé la sua famiglia curata',
    );
    expect(nuova.simpleColors, isEmpty);
    expect(settings.activePaletteId, nuova.id);
    expect(palettes.custom, hasLength(1), reason: 'un tema tuo, non due');

    // E una **seconda** scelta riscrive quello, senza crearne un altro. Il
    // foglio resta aperto dopo la scelta (non c'è niente da confermare),
    // quindi la ruota si riapre dalla casella già in schermata: toccare la
    // riga delle impostazioni dietro il foglio, oltre a non servire, cade
    // sulla barriera modale e **chiude** il foglio.
    final altroDue = find.byKey(const ValueKey('altro-colore'));
    await tester.ensureVisible(altroDue);
    await tester.pumpAndSettle();
    await tester.tap(altroDue);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pronto-#e57373')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usa questo'));
    await tester.pumpAndSettle();

    expect(palettes.custom, hasLength(1));
    expect(attiva().id, PaletteController.myColorId);
    expect(attiva().seedHex, '#e57373');

    // Il tema pronto è rimasto com'era.
    expect(palettes.byId('colore-verde')!.seedHex, '#43A047');
  });
}
