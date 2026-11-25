import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/ui/app_shell.dart';
import 'package:planner/ui/shared/view_push_switcher.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/sync/sync_service.dart';
import 'package:planner/core/sync/unconfigured_sync_auth.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/sync/sync_controller.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/filters/filtro_condiviso_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_selection.dart';
import 'package:planner/features/todos/todo_filter_controller.dart';

import 'support/finders.dart';

/// Guardia contro il fallimento della v2: `flutter analyze` pulito mentre
/// l'app non mostrava niente. Il guscio spediava 4 pagine segnaposto mentre i
/// widget veri erano codice morto — e nessun test lo beccava.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Future<AppSettingsController> pumpApp(WidgetTester tester) async {
    // Gli stessi provider che monta `main()`, **nello stesso ordine**: prima le
    // palette e il loro allineamento (che può spostare il tema attivo), poi le
    // preferenze — che il tema lo leggono.
    final palettes = PaletteController(db)
      ..load()
      ..allineaPresets();
    final settings = AppSettingsController(db.settings)..load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: palettes),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
          ChangeNotifierProvider(create: (_) => SelezioneDeiTodo()),
          ChangeNotifierProvider(create: (_) => CategoryController(db)),
          ChangeNotifierProvider(
            create: (_) => TodoFilterController(db.settings)..load(),
          ),
          // Calendario e agenda leggono anche il filtro condiviso (#92).
          ChangeNotifierProvider(
            create: (_) => FiltroCondivisoController(db.settings)..load(),
          ),
          ChangeNotifierProvider(create: (_) => NoteProvider(db)),
          ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
          // Il guscio ora ha anche la pagina delle impostazioni di sync: senza
          // il controller, pompare l'app lancia ProviderNotFoundException.
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
    return settings;
  }

  testWidgets('all\'avvio la migrazione del tema arriva alle impostazioni',
      (tester) async {
    // Un tema vecchio ancora attivo, come dopo l'aggiornamento: la migrazione
    // lo sposta sul più vicino e **quello** deve essere il tema letto.
    db.palettes.upsert({
      'id': 'preset-inverno',
      'name': 'Inverno',
      'seed_hex': '#1565C0',
      'colors_json': '[]',
      'is_preset': 1,
      'version': 1,
    });
    db.settings.set(AppSettingsController.activePaletteKey, 'preset-inverno');

    final settings = await pumpApp(tester);

    expect(settings.activePaletteId, 'colore-blu',
        reason: 'la migrazione sposta sul più vicino e il tema si legge dopo');
  });

  testWidgets('every tab renders its real widget, not a placeholder',
      (tester) async {
    await pumpApp(tester);

    // Calendar: the real page builds a TableCalendar.
    expect(calendarFinder, findsOneWidget);

    await tester.tap(find.text('To do'));
    await tester.pumpAndSettle();
    expect(find.text('Nessun To do'), findsOneWidget);

    // Note: pagina vera, con ricerca e stato vuoto.
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cerca-note')), findsOneWidget);
    expect(find.text('Nessuna nota'), findsOneWidget);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Niente in programma'), findsOneWidget);
  });

  testWidgets('an event stored in SQLite reaches the agenda', (tester) async {
    // L'evento è "oggi alle 9": la finestra dell'agenda parte da oggi, quindi
    // la data non può essere scritta fissa — a mezzanotte il test cambierebbe
    // esito (successo a mezzanotte passata, appunto).
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day, 9);
    db.insertEvent({
      'id': 'e1',
      'title': 'Dentista',
      'start_time': start.millisecondsSinceEpoch,
      'end_time': start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    });

    await pumpApp(tester);
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();

    expect(find.text('Dentista'), findsOneWidget);
  });

  testWidgets('tocchi ravvicinati e cambio della preferenza di movimento',
      (tester) async {
    final settings = await pumpApp(tester);
    final tabs = find.byType(ViewPushSwitcher).first;
    await tester.tap(find.text('Note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final notes = find.ancestor(
      of: find.byKey(const ValueKey('cerca-note')),
      matching: find.byType(FractionalTranslation),
    );
    expect(tester.widget<FractionalTranslation>(notes.first).translation.dx,
        isNot(0));

    await tester.tap(find.text('Agenda'));
    await tester.pump();
    settings.setAnimationsEnabled(false);
    await tester.pumpAndSettle();

    expect(tester.widget<ViewPushSwitcher>(tabs).animate, isFalse);
    expect(find.text('Niente in programma'), findsOneWidget);
    final agenda = find.ancestor(
      of: find.text('Niente in programma'),
      matching: find.byType(FractionalTranslation),
    );
    expect(
        tester.widget<FractionalTranslation>(agenda.first).translation.dx, 0);
    expect(tester.takeException(), isNull);
  });
}
