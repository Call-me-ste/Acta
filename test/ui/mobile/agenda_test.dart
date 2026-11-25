import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/filters/filtro_condiviso_controller.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_recurrence.dart';
import 'package:planner/features/todos/todo_selection.dart';
import 'package:planner/theme/color_resolver.dart';
import 'package:planner/ui/mobile/agenda_event_box.dart';
import 'package:planner/ui/mobile/agenda_page.dart';
import 'package:planner/ui/mobile/item_form.dart';

/// L'agenda **raggruppata per giorno**: un gruppo per i giorni che hanno
/// qualcosa, l'ordine giusto dentro il giorno, e i due gesti (tocco apre,
/// scorrimento elimina con l'annulla).
void main() {
  late DatabaseService db;
  late EventProvider events;
  late TodoProvider todos;
  late AppSettingsController settings;
  late FiltroCondivisoController filtro;

  // Un giorno fisso: un test che cambia esito a mezzanotte non è una prova.
  final oggi = DateTime(2026, 9, 14);
  final domani = DateTime(2026, 9, 15);

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
    todos = TodoProvider(db);
    settings = AppSettingsController(db.settings)..load();
    filtro = FiltroCondivisoController(db.settings)..load();

    // Il 15: un evento di giornata intera, due con l'orario (in disordine di
    // inserimento apposta) e un todo.
    await events.addEvent(
      title: 'Festa',
      start: DateTime(2026, 9, 15),
      end: DateTime(2026, 9, 16),
      allDay: true,
    );
    await events.addEvent(
      title: 'Dentista',
      start: DateTime(2026, 9, 15, 15),
      end: DateTime(2026, 9, 15, 16),
      colorIndex: 0,
    );
    await events.addEvent(
      title: 'Lezione',
      start: DateTime(2026, 9, 15, 9),
      end: DateTime(2026, 9, 15, 11),
      colorIndex: 3,
    );
    await todos.addTodo(title: 'Bolletta', dueDate: domani);
    // Il 17: un todo da solo, che è un gruppo **senza eventi**.
    await todos.addTodo(title: 'Spesa', dueDate: DateTime(2026, 9, 17));
    // Il 16 non ha niente: non deve fare nessuna intestazione.
  });

  tearDown(() => db.close());

  Future<void> apri(WidgetTester tester) async {
    // Lo schermo di prova è più corto di un telefono: la lista è pigra e i
    // gruppi sotto la piega non si costruirebbero nemmeno.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ChangeNotifierProvider<AppSettingsController>.value(value: settings),
          ChangeNotifierProvider<FiltroCondivisoController>.value(
              value: filtro),
          ChangeNotifierProvider.value(value: CategoryController(db)),
          ChangeNotifierProvider.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
          ChangeNotifierProvider(create: (_) => SelezioneDeiTodo()),
        ],
        child: MaterialApp(home: AgendaPage(oggi: oggi)),
      ),
    );
    await tester.pumpAndSettle();
  }

  double sopra(WidgetTester tester, String testo) =>
      tester.getTopLeft(find.text(testo)).dy;

  testWidgets('un gruppo per giorno, e nessuna intestazione per i vuoti',
      (tester) async {
    await apri(tester);

    // I tre giorni con qualcosa: 15, 16 (il todo della spesa è il 17)… e il 14
    // (oggi) no, perché è vuoto.
    expect(find.text('14'), findsNothing, reason: 'oggi è vuoto');
    expect(find.text('15'), findsOneWidget);
    expect(find.text('16'), findsNothing);
    expect(find.text('17'), findsOneWidget);

    // I giorni col loro nome: il 15 settembre 2026 è un martedì, il 17 un
    // giovedì. Il 14 (lunedì) e il 16 restano **senza** intestazione.
    expect(find.text('mar'), findsOneWidget);
    expect(find.text('gio'), findsOneWidget);
    expect(find.text('lun'), findsNothing, reason: 'il 14 è vuoto');
    expect(find.text('mer'), findsNothing, reason: 'il 16 è vuoto');
    // Il conteggio: 3 eventi (2 con orario + 1 di giornata intera) e 2 To do.
    expect(find.text('3 eventi · 2 To do'), findsOneWidget);
  });

  testWidgets(
      'dentro il giorno: prima il tutto-il-giorno, poi gli orari, poi i todo',
      (tester) async {
    await apri(tester);

    expect(sopra(tester, 'Festa'), lessThan(sopra(tester, 'Lezione')));
    expect(sopra(tester, 'Lezione'), lessThan(sopra(tester, 'Dentista')),
        reason: 'le 9 prima delle 15');
    expect(sopra(tester, 'Dentista'), lessThan(sopra(tester, 'Bolletta')),
        reason: 'i todo stanno sotto gli eventi');
  });

  testWidgets('il tocco su un box apre la scheda, poi il form', (tester) async {
    await apri(tester);

    await tester.tap(find.byType(AgendaEventBox).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dettaglio-modifica')), findsOneWidget);
    expect(find.byType(ItemForm), findsNothing);

    await tester.tap(find.byKey(const ValueKey('dettaglio-modifica')));
    await tester.pumpAndSettle();
    expect(find.byType(ItemForm), findsOneWidget);
    expect(find.text('Modifica'), findsOneWidget);
  });

  testWidgets(
      'un giorno affollato costruisce solo le righe vicine allo schermo',
      (tester) async {
    final orario = DateTime(2026, 9, 15, 12);
    db.runInTransaction(() {
      for (var i = 0; i < 180; i++) {
        db.insertEvent({
          'id': 'carico-$i',
          'title': 'Evento di carico $i',
          'start_time': orario.millisecondsSinceEpoch,
          'end_time':
              orario.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
        });
      }
    });
    events.reload();
    await apri(tester);

    expect(find.text('183 eventi · 2 To do'), findsOneWidget);
    expect(find.byType(AgendaEventBox).evaluate().length, lessThan(40));
    expect(find.text('Bolletta'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Bolletta'),
      440,
      maxScrolls: 70,
    );
    expect(find.text('Bolletta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lo scorrimento elimina, e l\'annulla rimette', (tester) async {
    await apri(tester);

    await tester.drag(find.text('Dentista'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Dentista'), findsNothing);
    expect(find.text('Evento eliminato'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    // Torna **al suo posto**: stesso giorno, stessa ora.
    expect(find.text('Dentista'), findsOneWidget);
    expect(
      sopra(tester, 'Lezione'),
      lessThan(sopra(tester, 'Dentista')),
      reason: 'la posizione dentro il giorno non cambia',
    );
  });

  testWidgets('anche il tocco prolungato elimina, con l\'annulla',
      (tester) async {
    await apri(tester);

    await tester.longPress(find.text('Festa'));
    await tester.pumpAndSettle();

    expect(find.text('Festa'), findsNothing);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(find.text('Festa'), findsOneWidget);
  });

  testWidgets('i todo seguono la modalità: compatta e pieni sì, nascosta no',
      (tester) async {
    await apri(tester);
    expect(find.text('Bolletta'), findsOneWidget);

    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await tester.pumpAndSettle();
    expect(find.text('Bolletta'), findsOneWidget);
    expect(find.text('3 eventi · 2 To do'), findsOneWidget);

    // «Nascosta»: nessun todo fuori dalla scheda Todo — quindi nemmeno qui.
    settings.setTodoInCalendario(TodoInCalendario.nascosta);
    await tester.pumpAndSettle();
    expect(find.text('Bolletta'), findsNothing);
    expect(find.text('Spesa'), findsNothing);
    expect(find.text('3 eventi'), findsOneWidget);

    // E il gruppo del 17 (solo todo) sparisce con loro: era un gruppo di niente.
    expect(find.text('17'), findsNothing);
  });

  testWidgets('una todo fatta resta in agenda, barrata e contata',
      (tester) async {
    await apri(tester);

    await todos
        .toggleTodo(todos.todos.firstWhere((t) => t.title == 'Bolletta').id);
    await tester.pumpAndSettle();

    // L'agenda non e' il calendario: qui il fatto **resta** (si vede che e'
    // fatto), e resta anche nel conteggio. A toglierlo dal calendario e' il segno
    // «via dal calendario», che qui non c'e'.
    expect(find.text('Bolletta'), findsOneWidget);
    expect(find.text('3 eventi · 2 To do'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Bolletta')).style?.decoration,
      TextDecoration.lineThrough,
      reason: 'barrata: si vede a colpo d\'occhio che e\' fatta',
    );
  });

  testWidgets('le scritte degli eventi sono tutte dello stesso colore',
      (tester) async {
    await apri(tester);

    // Due box con colori **diversi** della famiglia (indice 0 e 3): con la
    // scelta per box le due scritte uscivano una bianca e una nera.
    Color sfondo(String titolo) => tester
        .widget<Material>(
          find.descendant(
            of: find.widgetWithText(AgendaEventBox, titolo),
            matching: find.byType(Material),
          ),
        )
        .color!;
    expect(
      sfondo('Lezione'),
      isNot(sfondo('Dentista')),
      reason: 'i due box hanno colori diversi: il test è significativo',
    );

    final scritte = [
      tester.widget<Text>(find.text('Lezione')).style?.color,
      tester.widget<Text>(find.text('Dentista')).style?.color,
    ];
    expect(scritte, everyElement(isNotNull));
    expect(scritte.first, scritte.last,
        reason: 'un solo colore di testo per tema');
    expect(scritte.first, ColorResolver.agendaTesto(Brightness.light),
        reason: 'nel tema chiaro il testo degli eventi è nero');
  });
}
