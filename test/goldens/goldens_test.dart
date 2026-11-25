@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/sync/sync_service.dart';
import 'package:planner/core/sync/unconfigured_sync_auth.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/backup/backup_controller.dart';
import 'package:planner/features/backup/backup_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/domain/palette.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/sync/sync_controller.dart';
import 'package:planner/features/notifications/notification_settings_controller.dart';
import 'package:planner/features/notifications/notification_sink.dart';

import '../support/fake_notification_sink.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/todos/todo_filter_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_selection.dart';
import 'package:planner/theme/app_theme.dart';
import 'package:planner/ui/mobile/backup_page.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/colore_sheet.dart';
import 'package:planner/ui/mobile/item_form.dart';
import 'package:planner/ui/mobile/item_type.dart';
import 'package:planner/ui/mobile/theme_preview.dart';
import 'package:planner/ui/mobile/note_editor_page.dart';
import 'package:planner/ui/mobile/notes_page.dart';
import 'package:planner/ui/mobile/notifications_page.dart';
import 'package:planner/ui/mobile/settings_page.dart';
import 'package:planner/ui/mobile/sync_settings_page.dart';
import 'package:planner/ui/mobile/todo_page.dart';
import 'package:planner/ui/shared/color_field.dart';

/// Golden: quattro schermate (calendario e impostazioni, chiaro e scuro) su due
/// palette.
///
/// Non verificano il comportamento — lo fanno gli altri test — ma che **l'aspetto
/// non cambi da solo**: un raggio, un colore o un'ombra spostati per sbaglio si
/// vedono qui come differenza di pixel.
///
/// Due accortezze perché siano stabili:
///
/// * **Mese lontano da oggi**: il calendario evidenzia il giorno corrente, quindi
///   un mese che contiene oggi cambierebbe il golden ogni giorno. Gennaio 2030
///   non conterrà "oggi" finché non arriva il 2030.
/// * **Palette e tema fissati a mano**: il golden non deve dipendere da cosa c'è
///   nelle preferenze di chi lo esegue.
///
/// Sono sensibili ai font e al renderer: su una macchina diversa si rigenerano
/// (`flutter test --update-goldens test/goldens/`) oppure si escludono
/// (`flutter test --exclude-tags golden`).
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    required Widget page,
    required String paletteId,
    required bool dark,
    Size physicalSize = const Size(1080, 2400),
    bool notificheAttive = false,
    List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final palettes = PaletteController(db)
      ..load()
      ..allineaPresets();
    final settings = AppSettingsController(db.settings)
      ..load()
      ..setActivePalette(paletteId)
      ..setThemeMode(
        dark
            ? AppSettingsController.themeDark
            : AppSettingsController.themeLight,
      );

    final palette = palettes.resolve(settings.activePaletteId);
    final notifiche = NotificationSettingsController(db.settings)..load();
    if (notificheAttive) notifiche.setAttive(true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PaletteController>.value(value: palettes),
          ChangeNotifierProvider<AppSettingsController>.value(value: settings),
          ChangeNotifierProvider<NotificationSettingsController>.value(
            value: notifiche,
          ),
          Provider<NotificationSink>.value(value: FakeNotificationSink()),
          ChangeNotifierProvider<CategoryController>.value(
            value: CategoryController(db),
          ),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
          // La scheda Todo legge anche i filtri (e la selezione, per la barra
          // contestuale).
          ChangeNotifierProvider(
            create: (_) => TodoFilterController(db.settings)..load(),
          ),
          ChangeNotifierProvider(create: (_) => SelezioneDeiTodo()),
          ...extraProviders,
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark(palette) : AppTheme.light(palette),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('calendario chiaro (classico)', (tester) async {
    await pump(
      tester,
      page: CalendarPage(initialDay: DateTime(2030, 1, 15)),
      paletteId: 'colore-blu',
      dark: false,
      extraProviders: [Provider.value(value: db)],
    );
    await expectLater(
      find.byType(CalendarPage),
      matchesGoldenFile('goldens/calendario_chiaro.png'),
    );
  });

  testWidgets('calendario scuro (classico)', (tester) async {
    await pump(
      tester,
      page: CalendarPage(initialDay: DateTime(2030, 1, 15)),
      paletteId: 'colore-blu',
      dark: true,
      extraProviders: [Provider.value(value: db)],
    );
    await expectLater(
      find.byType(CalendarPage),
      matchesGoldenFile('goldens/calendario_scuro.png'),
    );
  });

  /// Il **foglio dei colori**: le tre righe (anteprima, colore principale con i
  /// quattordici nomi e la casella della ruota, altri temi) e nessun codice. E' la
  /// schermata che l'utente ha chiesto di semplificare, quindi vale un golden suo.
  testWidgets('foglio dei colori (chiaro)', (tester) async {
    await pump(
      tester,
      page: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showColoreSheet(context),
              child: const Text('Colori'),
            ),
          ),
        ),
      ),
      paletteId: 'colore-blu',
      dark: false,
      // Il foglio è alto (tre righe): uno schermo più alto del telefono, così si
      // vede tutto quello che c'è dentro e il golden dice la verità.
      physicalSize: const Size(1080, 4200),
    );
    await tester.tap(find.text('Colori'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RigaDelFoglio).first,
      matchesGoldenFile('goldens/foglio_colori_chiaro.png'),
    );
  });

  testWidgets('scheda todo chiaro (classico)', (tester) async {
    // La scheda Todo entra nei golden da qui: l'intestazione (dove sei, quanti,
    // i filtri) e' una zona con una gerarchia sua, e un golden la difende dai
    // ritocchi involontari.
    await pump(
      tester,
      page: const TodoPage(),
      paletteId: 'colore-blu',
      dark: false,
    );
    await expectLater(
      find.byType(TodoPage),
      matchesGoldenFile('goldens/todo_chiaro.png'),
    );
  });

  testWidgets('note chiaro (classico)', (tester) async {
    final notes = NoteProvider(db);
    final folder = await notes.addFolder(name: 'Lavoro', colorIndex: 6);
    await notes.addNote(
      title: 'Riunione progetto',
      content: 'Portare il piano e le note della settimana.',
      folderId: folder.id,
    );
    await notes.addNote(
        title: 'Idee', content: '#idee Rivedere la schermata Note.');
    final pinnata = await notes.addNote(
      title: 'Spesa',
      content: 'Latte, pane e caffè.',
    );
    await notes.togglePinned(pinnata);

    await pump(
      tester,
      page: const NotesPage(),
      paletteId: 'colore-blu',
      dark: false,
      extraProviders: [
        ChangeNotifierProvider<NoteProvider>.value(value: notes),
        ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
      ],
    );
    await expectLater(
      find.byType(NotesPage),
      matchesGoldenFile('goldens/note_chiaro.png'),
    );
  });

  testWidgets('note vuote (classico)', (tester) async {
    final notes = NoteProvider(db);

    await pump(
      tester,
      page: const NotesPage(),
      paletteId: 'colore-blu',
      dark: false,
      extraProviders: [
        ChangeNotifierProvider<NoteProvider>.value(value: notes),
        ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
      ],
    );
    await expectLater(
      find.byType(NotesPage),
      matchesGoldenFile('goldens/note_vuote.png'),
    );
  });

  testWidgets('note in selezione (classico)', (tester) async {
    final notes = NoteProvider(db);
    await notes.addNote(title: 'Prima nota', content: 'Testo della prima.');
    final seconda = await notes.addNote(
        title: 'Seconda nota', content: 'Testo della seconda.');
    // Fissata: dà un ordine stabile al golden (le due note nascono nello stesso
    // istante e l'ordinamento per data non basta a distinguerle).
    await notes.togglePinned(seconda);

    await pump(
      tester,
      page: const NotesPage(),
      paletteId: 'colore-blu',
      dark: false,
      extraProviders: [
        ChangeNotifierProvider<NoteProvider>.value(value: notes),
        ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
      ],
    );
    await tester.longPress(find.text('Prima nota'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NotesPage),
      matchesGoldenFile('goldens/note_selezione.png'),
    );
  });

  testWidgets('note scuro (classico)', (tester) async {
    final notes = NoteProvider(db);
    final folder = await notes.addFolder(name: 'Lavoro', colorIndex: 6);
    await notes.addNote(
      title: 'Riunione progetto',
      content: 'Portare il piano e le note della settimana.',
      folderId: folder.id,
    );
    await notes.addNote(
        title: 'Idee', content: '#idee Rivedere la schermata Note.');

    await pump(
      tester,
      page: const NotesPage(),
      paletteId: 'colore-blu',
      dark: true,
      extraProviders: [
        ChangeNotifierProvider<NoteProvider>.value(value: notes),
        ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
      ],
    );
    await expectLater(
      find.byType(NotesPage),
      matchesGoldenFile('goldens/note_scuro.png'),
    );
  });

  testWidgets('editor nota chiaro (classico)', (tester) async {
    final notes = NoteProvider(db);
    final nota = await notes.addNote(
      title: 'Piano settimana',
      content:
          'Fare:\n- [ ] latte\n- [x] pane\n- riunione\n1. preparare il piano',
    );
    // La data mostrata nell'editor è un dato: nel golden va fissata, altrimenti
    // il file cambia a ogni esecuzione.
    db.notes.update(
      nota.copyWith(updatedAt: DateTime(2026, 10, 20, 18, 30)).toParams(),
    );
    final ricaricate = NoteProvider(db);
    final fissata = ricaricate.byId(nota.id)!;

    await pump(
      tester,
      page: NoteEditorPage(note: fissata),
      paletteId: 'colore-blu',
      dark: false,
      extraProviders: [
        ChangeNotifierProvider<NoteProvider>.value(value: ricaricate),
      ],
    );
    await expectLater(
      find.byType(NoteEditorPage),
      matchesGoldenFile('goldens/note_editor_chiaro.png'),
    );
  });

  testWidgets('impostazioni chiaro (primavera)', (tester) async {
    await pump(
      tester,
      page: const SettingsPage(),
      paletteId: 'colore-verde',
      dark: false,
    );
    await expectLater(
      find.byType(SettingsPage),
      matchesGoldenFile('goldens/impostazioni_chiaro.png'),
    );
  });

  testWidgets('impostazioni scuro (primavera)', (tester) async {
    await pump(
      tester,
      page: const SettingsPage(),
      paletteId: 'colore-verde',
      dark: true,
    );
    await expectLater(
      find.byType(SettingsPage),
      matchesGoldenFile('goldens/impostazioni_scuro.png'),
    );
  });

  for (final dark in [false, true]) {
    final tema = dark ? 'scuro' : 'chiaro';

    testWidgets('notifiche $tema', (tester) async {
      await pump(
        tester,
        page: const NotificationsPage(),
        paletteId: 'colore-verde',
        dark: dark,
        notificheAttive: true,
        physicalSize: const Size(1080, 3000),
      );
      await expectLater(
        find.byType(NotificationsPage),
        matchesGoldenFile('goldens/notifiche_$tema.png'),
      );
    });

    testWidgets('backup $tema', (tester) async {
      final settings = AppSettingsController(db.settings)..load();
      final copie = BackupController(
        db,
        settings,
        servizio: BackupService(db, cartella: Directory('build/golden-backup')),
      );
      final sync = SyncController(
        auth: const UnconfiguredSyncAuthService(),
        sync: SyncService(db),
        createGateway: () => throw StateError('non configurato'),
      );
      await pump(
        tester,
        page: const BackupPage(),
        paletteId: 'colore-verde',
        dark: dark,
        extraProviders: [
          ChangeNotifierProvider<BackupController>.value(value: copie),
          ChangeNotifierProvider<SyncController>.value(value: sync),
        ],
      );
      await expectLater(
        find.byType(BackupPage),
        matchesGoldenFile('goldens/backup_$tema.png'),
      );
    });

    testWidgets('sincronizzazione $tema', (tester) async {
      final sync = SyncController(
        auth: const UnconfiguredSyncAuthService(),
        sync: SyncService(db),
        createGateway: () => throw StateError('non configurato'),
      );
      await pump(
        tester,
        page: const SyncSettingsPage(),
        paletteId: 'colore-verde',
        dark: dark,
        extraProviders: [
          ChangeNotifierProvider<SyncController>.value(value: sync)
        ],
      );
      await expectLater(
        find.byType(SyncSettingsPage),
        matchesGoldenFile('goldens/sync_$tema.png'),
      );
    });
  }

  /// Il **selettore del colore**: la ruota, la barra della luminosità, i colori
  /// pronti e il codice. È l'unico posto dove si sceglie un colore in tutta l'app
  /// (categorie, eventi, todo, tema), quindi vale un golden suo: la ruota è
  /// disegnata a mano, ed è esattamente il tipo di cosa che si rompe senza che
  /// nessun test di comportamento se ne accorga.
  testWidgets('selettore colore (chiaro)', (tester) async {
    await pump(
      tester,
      // Il `Builder` serve a costruire il pulsante **dentro** il tema: così il
      // dialogo legge lo schema vero, quello che l'app userà.
      page: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showColorDialog(context, initialHex: '#3f51b5'),
              child: const Text('Colore'),
            ),
          ),
        ),
      ),
      paletteId: 'colore-blu',
      dark: false,
      // Il dialogo con la ruota è alto: uno schermo più alto del telefono, così
      // il golden lo comprende tutto (barra, pronti e pulsanti).
      physicalSize: const Size(1080, 3000),
    );

    await tester.tap(find.text('Colore'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AlertDialog),
      matchesGoldenFile('goldens/selettore_colore_chiaro.png'),
    );
  });

  /// L'anteprima del modo **semplice** dei colori: i ruoli scelti a mano
  /// (fondo, superfici, testo, accento) sopra lo schema del seed.
  ///
  /// Serve a fermare l'aspetto, non il comportamento: se un giorno qualcuno tocca
  /// l'anteprima, qui si vede come differenza di pixel.
  const semplice = Palette(
    id: 'il-mio-colore',
    name: 'Semplice',
    seedHex: '#3f51b5',
    colors: [],
    simpleColors: {
      'surface': '#f6f1e7',
      'surfaceContainer': '#e8dfd0',
      'onSurface': '#1c1a17',
      'primary': '#8b3a2f',
    },
  );

  for (final scuro in [false, true]) {
    testWidgets('anteprima dei colori ${scuro ? 'scuro' : 'chiaro'}',
        (tester) async {
      await PaletteController(db).save(semplice);
      await pump(
        tester,
        // Il `Builder` serve a costruire l'anteprima **dentro** il tema: così
        // legge lo schema vero, quello che l'app userà.
        page: Builder(
          builder: (context) => Scaffold(
            body: ThemePreview(scheme: Theme.of(context).colorScheme),
          ),
        ),
        paletteId: 'il-mio-colore',
        dark: scuro,
        physicalSize: const Size(600, 600),
      );
      await expectLater(
        find.byType(ThemePreview),
        matchesGoldenFile(
          'goldens/anteprima_colori_${scuro ? 'scuro' : 'chiaro'}.png',
        ),
      );
    });
  }

  // Il form in **modifica**: è il caso che mostra tutto (righe, colore,
  // ricorrenza, Elimina e Salva) e non ha il campo titolo a fuoco — un cursore
  // che lampeggia renderebbe il golden instabile.
  testWidgets('form chiaro (classico)', (tester) async {
    await pump(
      tester,
      page: await formDiProva(dark: false),
      paletteId: 'colore-blu',
      dark: false,
      // Tela più alta del telefono: il form è lungo (e dal 2026-09-17 ha anche
      // promemoria, posizione e note), e senza questo il golden taglierebbe
      // proprio la barra dei pulsanti (Elimina e Salva).
      physicalSize: const Size(1080, 4400),
    );
    await expectLater(
      find.byType(ItemForm),
      matchesGoldenFile('goldens/form_chiaro.png'),
    );
  });

  testWidgets('form scuro (classico)', (tester) async {
    await pump(
      tester,
      page: await formDiProva(dark: true),
      paletteId: 'colore-blu',
      dark: true,
      physicalSize: const Size(1080, 4400),
    );
    await expectLater(
      find.byType(ItemForm),
      matchesGoldenFile('goldens/form_scuro.png'),
    );
  });
}

/// Il form dentro uno `Scaffold`, con un evento finto già scritto nel database:
/// serve a renderlo in **modifica** (senza autofocus) e con i suoi valori.
Future<Widget> formDiProva({required bool dark}) async {
  final db = DatabaseService();
  await db.init(dbPath: ':memory:');
  final events = EventProvider(db);
  await events.addEvent(
    title: 'Riunione',
    start: DateTime(2030, 1, 15, 9, 30),
    end: DateTime(2030, 1, 15, 10, 30),
  );

  return _FormConProvider(db: db, evento: events.events.single);
}

/// Il form con i suoi provider: uno `Scaffold` perché il foglio del form non ne
/// porta uno (ci pensa chi lo apre).
class _FormConProvider extends StatelessWidget {
  const _FormConProvider({required this.db, required this.evento});

  final DatabaseService db;
  final Event evento;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EventProvider(db)),
        ChangeNotifierProvider(create: (_) => TodoProvider(db)),
      ],
      child: Scaffold(
        body: ItemForm(
          type: ItemType.evento,
          day: DateTime(2030, 1, 15),
          event: evento,
        ),
      ),
    );
  }
}
