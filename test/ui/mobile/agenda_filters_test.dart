import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/filters/filtro_condiviso.dart';
import 'package:planner/features/filters/filtro_condiviso_controller.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_selection.dart';
import 'package:planner/ui/mobile/agenda_page.dart';

/// La barra dei filtri dell'agenda: le tre scelte, le categorie a scelta
/// multipla, l'orizzonte che cambia i giorni, e il conteggio che segue.
void main() {
  late DatabaseService db;
  late EventProvider events;
  late TodoProvider todos;
  late CategoryController categorie;
  late FiltroCondivisoController filtro;

  final oggi = DateTime(2026, 9, 14);
  var lavoro = '';
  var casa = '';

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
    todos = TodoProvider(db);
    categorie = CategoryController(db);
    filtro = FiltroCondivisoController(db.settings)..load();

    lavoro = (await categorie.create(name: 'Lavoro')).id;
    casa = (await categorie.create(name: 'Casa')).id;

    // Uno fra tre giorni (dentro i 7), uno fra venti (fuori dai 7, dentro i 30)
    // e uno fra quindici... no: due bastano per distinguere gli orizzonti.
    await events.addEvent(
      title: 'Vicino',
      start: DateTime(2026, 9, 16, 9),
      end: DateTime(2026, 9, 16, 10),
      categoryIds: [lavoro],
    );
    await events.addEvent(
      title: 'Lontano',
      start: DateTime(2026, 10, 4, 9),
      end: DateTime(2026, 10, 4, 10),
      categoryIds: [casa],
    );
    await todos.addTodo(title: 'Bolletta', dueDate: DateTime(2026, 9, 15));
  });

  tearDown(() => db.close());

  Future<void> apri(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ChangeNotifierProvider<CategoryController>.value(value: categorie),
          ChangeNotifierProvider<FiltroCondivisoController>.value(
              value: filtro),
          ChangeNotifierProvider(
            create: (_) => AppSettingsController(db.settings)..load(),
          ),
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

  /// Le pastiglie stanno su una riga **scorrevole** (col testo ingrandito non ci
  /// stanno): nei test il carattere è largo, quindi la seconda e la terza sono
  /// fuori schermo finché non si scorre. È il comportamento voluto, non un
  /// inciampo: qui si scorre come farebbe un dito.
  Future<void> toccaPastiglia(WidgetTester tester, String chiave) async {
    final pastiglia = find.byKey(ValueKey(chiave));
    await tester.ensureVisible(pastiglia);
    await tester.pumpAndSettle();
    await tester.tap(pastiglia);
    await tester.pumpAndSettle();
  }

  Future<void> scegli(WidgetTester tester, String voce) async {
    await tester.tap(find.byKey(ValueKey('scelta-$voce')));
    await tester.pumpAndSettle();
  }

  testWidgets('«cosa mostrare»: tutto, solo eventi, solo todo', (tester) async {
    await apri(tester);
    expect(find.text('Vicino'), findsOneWidget);
    expect(find.text('Bolletta'), findsOneWidget);

    // Il foglio si apre dalla pastiglia, e dice dove sei.
    await toccaPastiglia(tester, 'filtro-cosa');
    expect(find.byKey(const ValueKey('scelta-eventi')), findsOneWidget);

    await scegli(tester, 'eventi');

    expect(find.text('Vicino'), findsOneWidget);
    expect(find.text('Bolletta'), findsNothing);
    expect(find.text('Solo eventi'), findsOneWidget);
    // Il conteggio segue: i todo non ci sono piu'.
    expect(find.text('2 eventi'), findsOneWidget);

    await toccaPastiglia(tester, 'filtro-cosa');
    await scegli(tester, 'todo');

    expect(find.text('Vicino'), findsNothing);
    expect(find.text('Bolletta'), findsOneWidget);
    expect(find.text('1 To do'), findsOneWidget);
  });

  testWidgets('l\'orizzonte decide fin dove si guarda', (tester) async {
    await apri(tester);

    // Di partenza 30 giorni: ci sta dentro anche il 4 ottobre.
    expect(find.text('30 giorni'), findsOneWidget);
    expect(find.text('Lontano'), findsOneWidget);

    await toccaPastiglia(tester, 'filtro-orizzonte');
    await scegli(tester, 'giorni7');

    expect(find.text('7 giorni'), findsOneWidget);
    expect(find.text('Lontano'), findsNothing);
    expect(find.text('Vicino'), findsOneWidget);
    // E il conteggio dice quanti ne restano: uno solo.
    expect(find.text('1 evento · 1 To do'), findsOneWidget);

    // I novanta giorni sono **di piu'**, non di meno.
    await toccaPastiglia(tester, 'filtro-orizzonte');
    await scegli(tester, 'giorni90');

    expect(find.text('Lontano'), findsOneWidget);
    expect(find.text('2 eventi · 1 To do'), findsOneWidget);
  });

  testWidgets('le categorie si scelgono a piu\' d\'una, e il conteggio segue',
      (tester) async {
    await apri(tester);

    await toccaPastiglia(tester, 'filtro-categorie');
    expect(find.text('Nessun vincolo: si vede tutto.'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('filtro-categoria-$lavoro')));
    await tester.pumpAndSettle();
    expect(
        find.text('Si vede solo quello che ha una di queste.'), findsOneWidget);

    // Solo l'evento di «Lavoro»: il todo non ha categorie, e con una categoria
    // scelta passa solo quello che ce l'ha.
    expect(find.text('Vicino'), findsOneWidget);
    expect(find.text('Bolletta'), findsNothing);

    // Due scelte: tornano tutti e due gli eventi.
    await tester.tap(find.byKey(ValueKey('filtro-categoria-$casa')));
    await tester.pumpAndSettle();
    expect(find.text('Vicino'), findsOneWidget);
    expect(find.text('Lontano'), findsOneWidget);

    // Il foglio si chiude, e la pastiglia dice quante categorie si stanno
    // guardando.
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    expect(find.text('Categorie · 2'), findsOneWidget);

    // E togliendole tutte si torna a vedere tutto: il giro completo.
    await toccaPastiglia(tester, 'filtro-categorie');
    await tester.tap(find.byKey(ValueKey('filtro-categoria-$lavoro')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('filtro-categoria-$casa')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();

    expect(find.text('Categorie'), findsOneWidget);
    expect(filtro.filtro.categorieScelte, isEmpty);
    expect(find.text('Bolletta'), findsOneWidget);
  });

  testWidgets('con niente da mostrare la barra resta, e lo dice',
      (tester) async {
    await apri(tester);

    filtro.setCosa(CosaMostrare.todo);
    await tester.pumpAndSettle();
    filtro.setOrizzonte(Orizzonte.giorni7);
    await tester.pumpAndSettle();
    filtro.toggleCategoria(casa);
    await tester.pumpAndSettle();

    // In sette giorni, solo todo, solo «Casa»: non resta niente — e la barra c'e'
    // lo stesso, perche' e' da li' che si torna indietro.
    expect(find.text('Nessun risultato con questi filtri'), findsOneWidget);
    expect(find.byKey(const ValueKey('filtro-categorie')), findsOneWidget);
  });
}
