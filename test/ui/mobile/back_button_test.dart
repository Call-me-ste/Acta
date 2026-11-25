import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_selection.dart';
import 'package:planner/features/todos/todo_filter_controller.dart';
import 'package:planner/ui/mobile/bottom_bar.dart';
import 'package:planner/ui/mobile/mobile_shell.dart';

/// Il tasto indietro: prima la **posizione di prima**, poi l'avviso, e solo il
/// secondo tocco ravvicinato chiude l'app.
///
/// Perche' cosi': il calendario si tocca tutto il giorno e un indietro per sbaglio
/// che chiude l'app fa perdere il punto in cui eri. Perche' l'avviso scade: chi ha
/// sbagliato non deve trovarsi un messaggio appiccicato per sempre.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Widget harness() => MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: db),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
          ChangeNotifierProvider(create: (_) => SelezioneDeiTodo()),
          ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
          ChangeNotifierProvider(create: (_) => CategoryController(db)),
          ChangeNotifierProvider(
            create: (_) => TodoFilterController(db.settings)..load(),
          ),
          ChangeNotifierProvider.value(
            value: AppSettingsController(db.settings)..load(),
          ),
          ChangeNotifierProvider.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
        ],
        child: const MaterialApp(home: MobileShell()),
      );

  int schedaAttiva(WidgetTester tester) =>
      tester.widget<BottomBar>(find.byType(BottomBar)).index;

  testWidgets(
      "con una selezione aperta, l'indietro chiude quella e non cambia scheda",
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('To do'));
    await tester.pumpAndSettle();

    // Un todo creato dal provider, poi il tocco prolungato: la selezione
    // multipla si apre (#90).
    final todoProvider = Provider.of<TodoProvider>(
      tester.element(find.byType(MobileShell)),
      listen: false,
    );
    await todoProvider.addTodo(title: 'Bolletta', dueDate: DateTime.now());
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Bolletta'));
    await tester.pumpAndSettle();
    expect(find.text('1 selezionati'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Il tasto indietro ha fatto la cosa **piu' vicina**, non quella piu' grande:
    // la selezione e' chiusa e siamo ancora sulla scheda Todo. Senza il controller
    // sopra il guscio, il guscio avrebbe armato l'uscita dall'app.
    expect(find.text('1 selezionati'), findsNothing);
    expect(schedaAttiva(tester), 1);
  });

  testWidgets('il primo indietro torna alla posizione di prima',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('To do'));
    await tester.pumpAndSettle();
    expect(schedaAttiva(tester), 1, reason: 'Todo è la seconda voce');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      schedaAttiva(tester),
      BottomBar.centrale,
      reason: 'l\'indietro riporta alla scheda di prima (il Calendario, in '
          'mezzo), non chiude l\'app',
    );
  });

  testWidgets('a storia vuota: primo indietro avvisa, secondo chiude',
      (tester) async {
    // Spia sul canale di sistema: `SystemNavigator.pop()` e' la richiesta di
    // chiusura, e qui si intercetta invece di chiudere davvero.
    final chiamate = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        chiamate.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(
      find.text('Premi di nuovo per uscire'),
      findsOneWidget,
      reason: 'il primo indietro avvisa, non chiude',
    );
    expect(
      chiamate,
      isNot(contains('SystemNavigator.pop')),
      reason: 'il primo indietro non chiede di uscire: avvisa e basta '
          '(sul canale passano anche altre chiamate, per esempio il titolo '
          'dell\'app: si controlla quella, non l\'elenco intero)',
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(
      chiamate,
      contains('SystemNavigator.pop'),
      reason: 'il secondo indietro ravvicinato chiude',
    );
  });
}
