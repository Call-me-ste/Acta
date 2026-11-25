import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_filter_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_selection.dart';
import 'package:planner/ui/mobile/bottom_bar.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/mobile_shell.dart';
import 'package:planner/ui/mobile/notes_page.dart';

/// La barra in basso: **Note, Todo, Calendario (rialzato), Agenda,
/// Impostazioni**, e all'avvio il **Calendario**.
///
/// Perché il Calendario in mezzo e con la pastiglia: è la schermata che si guarda
/// di più. Perché la pastiglia è **del colore della barra**: deve fondersi con
/// essa (una collina), non sembrare un pulsante appoggiato sopra — è quello che
/// verificano queste prove, guardando i colori e la geometria invece dell'aspetto.
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
          ChangeNotifierProvider(create: (_) => NoteProvider(db)),
          ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
          ChangeNotifierProvider(create: (_) => SelezioneDeiTodo()),
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

  Future<void> apri(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
  }

  BottomBar barra(WidgetTester tester) =>
      tester.widget<BottomBar>(find.byType(BottomBar));

  testWidgets('le cinque voci, nell\'ordine chiesto', (tester) async {
    await apri(tester);

    final x = [
      for (final etichetta in [
        'Note',
        'To do',
        'Calendario',
        'Agenda',
        'Opzioni',
      ])
        tester.getCenter(find.text(etichetta)).dx,
    ];

    // Da sinistra a destra, e ognuna più a destra della precedente.
    for (var indice = 1; indice < x.length; indice++) {
      expect(
        x[indice],
        greaterThan(x[indice - 1]),
        reason: 'la voce $indice non è a destra di quella prima',
      );
    }
    expect(BottomBar.voci.length, 5);
    expect(BottomBar.centrale, 2, reason: 'il Calendario è in mezzo');
  });

  testWidgets('a testo 2.0 la barra cresce e non rimpicciolisce le etichette',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await apri(tester);

    expect(tester.getSize(find.byType(BottomBar)).height, greaterThan(88));
    expect(
      find.descendant(
        of: find.byType(BottomBar),
        matching: find.byType(FittedBox),
      ),
      findsNothing,
      reason: 'le etichette devono crescere, non essere ridotte a forza',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('le etichette sono allineate, Calendario compreso',
      (tester) async {
    await apri(tester);

    final centro = tester.getRect(find.text('Calendario')).top;
    final note = tester.getRect(find.text('Note')).top;
    final agenda = tester.getRect(find.text('Agenda')).top;
    final opzioni = tester.getRect(find.text('Opzioni')).top;

    expect(centro, closeTo(note, 0.5));
    expect(centro, closeTo(agenda, 0.5));
    expect(centro, closeTo(opzioni, 0.5));
  });

  testWidgets('Opzioni mantiene il nome accessibile Impostazioni',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await apri(tester);
      expect(find.text('Opzioni'), findsOneWidget);
      expect(find.bySemanticsLabel('Impostazioni'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('la pastiglia esce sopra il bordo della barra', (tester) async {
    await apri(tester);

    final pastiglia = tester.getRect(
      find.byKey(const ValueKey('barra-pastiglia')),
    );
    final totale = tester.getRect(find.byType(BottomBar));

    expect(pastiglia.width, BottomBar.diametroPastiglia);
    // La superficie della barra comincia sotto la collina: la pastiglia le sta
    // sopra di `rigonfiamento` pixel.
    expect(
      pastiglia.top,
      closeTo(totale.top, 1),
      reason: 'la collina parte dal bordo alto della barra',
    );
    expect(
      pastiglia.bottom,
      greaterThan(totale.top + BottomBar.rigonfiamento),
      reason: 'e affonda dentro la barra, non le sta appoggiata sopra',
    );
    expect(
      pastiglia.center.dx,
      closeTo(totale.center.dx, 1),
      reason: 'in mezzo alle cinque voci',
    );
  });

  testWidgets('la pastiglia ha il colore della barra (è una collina)',
      (tester) async {
    await apri(tester);

    final superficie = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(BottomBar),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    final pastiglia = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('barra-pastiglia')),
        matching: find.byType(Container),
      ),
    );
    final decorazione = pastiglia.decoration! as BoxDecoration;

    expect(decorazione.color, superficie.color);
    expect(
      decorazione.shape,
      BoxShape.circle,
    );
  });

  testWidgets('l\'app si apre sul Calendario, che è la voce in mezzo',
      (tester) async {
    await apri(tester);

    expect(barra(tester).index, BottomBar.centrale);
    expect(find.byType(CalendarPage), findsOneWidget);
    expect(find.byType(NotesPage), findsNothing, reason: 'non è la prima');
  });

  testWidgets('il tocco cambia scheda, e la pastiglia riporta al Calendario',
      (tester) async {
    await apri(tester);

    // La parola «Note»: si tocca l'etichetta, non il cerchio.
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    expect(barra(tester).index, 0);
    expect(find.byType(NotesPage), findsOneWidget);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(barra(tester).index, 3);

    // Il Calendario si raggiunge dalla **pastiglia**, e anche dalla sua etichetta.
    await tester.tap(find.byKey(const ValueKey('barra-pastiglia')));
    await tester.pumpAndSettle();
    expect(barra(tester).index, BottomBar.centrale);
    expect(find.byType(CalendarPage), findsOneWidget);
  });

  testWidgets('il tocco sull\'etichetta del Calendario fa la stessa cosa',
      (tester) async {
    await apri(tester);

    await tester.tap(find.text('To do'));
    await tester.pumpAndSettle();
    expect(barra(tester).index, 1);

    // Chi mira alla parola invece che al cerchio deve ottenere la stessa cosa.
    await tester.tap(find.text('Calendario'));
    await tester.pumpAndSettle();
    expect(barra(tester).index, BottomBar.centrale);
  });

  testWidgets('la voce che si guarda è annunciata come selezionata',
      (tester) async {
    await apri(tester);

    final nodo = tester.getSemantics(
      find.byKey(const ValueKey('barra-pastiglia')),
    );
    expect(
      nodo,
      isSemantics(
        label: 'Calendario',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
  });
}
