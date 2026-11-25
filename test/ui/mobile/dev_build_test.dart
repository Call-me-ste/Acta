import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/database/settings_store.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/core/dev_flags.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/notifications/notification_settings_controller.dart';
import 'package:planner/features/notifications/notification_sink.dart';

import '../../support/fake_notification_sink.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/settings_page.dart';

/// **Le due build.** I comandi dei dati di prova sono attrezzi da banco, non
/// roba che sta nel telefono di chi usa l'app: esistono solo con
/// `--dart-define=dev=true`, e senza quel define la sezione non entra nel
/// binario (è una costante, quindi il ramo sparisce).
///
/// Perché è una prova sola e non due: `devTools` è una costante di
/// compilazione, quindi lo stesso test gira nei due modi e pretende la cosa
/// giusta in entrambi —
///   `flutter test`                     → la sezione non c'è
///   `flutter test --dart-define=dev=true` → la sezione c'è
/// Se la condizione sparisse dal codice, uno dei due giri diventa rosso.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  testWidgets('i dati di prova ci sono solo nella build di test',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AppSettingsController(db.settings)..load(),
          ),
          ChangeNotifierProvider(
            create: (_) => PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
          ChangeNotifierProvider(create: (_) => CategoryController(db)),
          ChangeNotifierProvider(
            create: (_) => NotificationSettingsController(db.settings)..load(),
          ),
          Provider<NotificationSink>.value(value: FakeNotificationSink()),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
          ChangeNotifierProvider(create: (_) => NoteProvider(db)),
          ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
          Provider<SettingsStore>.value(value: db.settings),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // La pagina è un elenco: la sezione sta in fondo, e senza scorrere non
    // verrebbe nemmeno costruita.
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(
      find.text('Dati di prova'),
      devTools ? findsOneWidget : findsNothing,
      reason: devTools
          ? 'nella build di test i comandi ci sono'
          : 'nella build ufficiale la sezione non deve esistere',
    );
    expect(find.byKey(const ValueKey('carica-demo')),
        devTools ? findsOneWidget : findsNothing);
  });
}
