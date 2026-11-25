import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/filters/filtro_condiviso.dart';
import 'package:planner/features/filters/filtro_condiviso_controller.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/day_view.dart';
import 'package:planner/ui/mobile/month_grid_painter.dart';
import 'package:planner/ui/mobile/week_view.dart';

/// Il filtro condiviso **dentro il calendario**: scegliendo una categoria, quello
/// che non ce l'ha sparisce dalle tre viste — e togliendo il filtro torna tutto.
///
/// Il giro completo (filtro -> niente -> filtro via -> tutto) non è pignoleria:
/// la finestra dei mesi e le celle sono in **memoria**, e senza la firma del
/// filtro la seconda metà del giro restituirebbe le celle di prima. È la stessa
/// trappola della modalità «todo nel calendario», e questo test la attraversa in
/// tutti e due i versi.
void main() {
  late DatabaseService db;
  late AppSettingsController settings;
  late FiltroCondivisoController filtro;
  late TodoProvider todos;
  late EventProvider events;
  late CategoryController categorie;

  final giorno = DateTime(2026, 9, 14);
  var casa = '';

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    settings = AppSettingsController(db.settings)..load();
    filtro = FiltroCondivisoController(db.settings)..load();
    categorie = CategoryController(db);
    todos = TodoProvider(db);
    events = EventProvider(db);

    final lavoro = (await categorie.create(name: 'Lavoro')).id;
    casa = (await categorie.create(name: 'Casa')).id;

    await events.addEvent(
      title: 'Lezione',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 11),
      categoryIds: [lavoro],
    );
    await events.addEvent(
      title: 'Dentista',
      start: DateTime(2026, 9, 14, 15),
      end: DateTime(2026, 9, 14, 16),
      categoryIds: [casa],
    );
    await todos.addTodo(
      title: 'Relazione',
      dueDate: giorno,
      categoryIds: [lavoro],
    );
    await todos.addTodo(title: 'Spesa', dueDate: giorno, categoryIds: [casa]);
  });

  tearDown(() => db.close());

  List<SingleChildWidget> providers() => [
        Provider<DatabaseService>.value(value: db),
        ChangeNotifierProvider.value(value: events),
        ChangeNotifierProvider.value(value: todos),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: filtro),
        ChangeNotifierProvider.value(value: categorie),
        ChangeNotifierProvider.value(
          value: PaletteController(db)
            ..load()
            ..allineaPresets(),
        ),
      ];

  Future<void> pumpCalendario(WidgetTester tester) async {
    // Lo schermo di prova (800x600) è più corto di un telefono: l'elenco sotto la
    // griglia è pigro e con la riga sotto la piega non la costruirebbe.
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: providers(),
        child: MaterialApp(home: CalendarPage(initialDay: giorno)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// I titoli degli eventi **di quella vista**, letti dal widget e non cercati
  /// con `find`: le tre viste restano vive (quella che non si guarda è
  /// `Offstage`) e la griglia del mese i titoli li disegna invece di costruirli.
  List<String> titoliDelGiorno(WidgetTester tester, DateTime day) => tester
      .widgetList<DayView>(find.byType(DayView, skipOffstage: false))
      .where((vista) => vista.day == day)
      .expand((vista) => vista.occurrences.map((o) => o.title))
      .toList();

  List<String> titoliDellaSettimana(WidgetTester tester) => tester
      .widget<WeekView>(find.byType(WeekView, skipOffstage: false))
      .occurrences
      .map((o) => o.title)
      .toList();

  /// Il numero scritto nel badge dei todo, giorno per giorno: i pallini nella
  /// griglia non sono widget (è un disegno solo), quindi si leggono dal painter.
  List<String> badge(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<GrigliaDelMese>()
      .expand((pennello) => pennello.giorni)
      .map((giorno) => giorno.badge?.plainText)
      .whereType<String>()
      .toList();

  testWidgets('in mese sparisce quello che non ha la categoria scelta',
      (tester) async {
    await pumpCalendario(tester);

    // Il filtro di partenza è "nessun vincolo": si vede tutto, badge compreso.
    expect(find.text('Lezione'), findsOneWidget);
    expect(find.text('Dentista'), findsOneWidget);
    expect(badge(tester), ['2']);

    filtro.toggleCategoria(casa);
    await tester.pumpAndSettle();

    // Scegliendo «Casa» spariscono l'evento **e** il todo dell'altra categoria,
    // e il badge dei todo scende a 1.
    expect(find.text('Lezione'), findsNothing);
    expect(find.text('Dentista'), findsOneWidget);
    expect(badge(tester), ['1']);

    // Il giro completo: tolto il filtro, torna tutto.
    filtro.toggleCategoria(casa);
    await tester.pumpAndSettle();

    expect(find.text('Lezione'), findsOneWidget);
    expect(find.text('Dentista'), findsOneWidget);
    expect(badge(tester), ['2']);
  });

  testWidgets('in settimana e in giorno sparisce la stessa cosa',
      (tester) async {
    await pumpCalendario(tester);
    filtro.toggleCategoria(casa);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();
    expect(titoliDellaSettimana(tester), ['Dentista']);

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();
    expect(titoliDelGiorno(tester, giorno), ['Dentista']);

    // E togliendo il filtro tornano tutte e due, **con le viste già in memoria**:
    // senza la firma nella chiave di `CalendarViewCache` questo pezzo non
    // tornerebbe.
    filtro.toggleCategoria(casa);
    await tester.pumpAndSettle();
    expect(titoliDelGiorno(tester, giorno), ['Lezione', 'Dentista']);
  });

  testWidgets('con «cosa mostrare» spariscono i todo, o gli eventi',
      (tester) async {
    await pumpCalendario(tester);

    filtro.setCosa(CosaMostrare.eventi);
    await tester.pumpAndSettle();
    // Gli eventi restano, i todo del calendario no: niente badge (né fascia).
    expect(find.text('Lezione'), findsOneWidget);
    expect(badge(tester), isEmpty);

    filtro.setCosa(CosaMostrare.todo);
    await tester.pumpAndSettle();
    expect(find.text('Lezione'), findsNothing);
    expect(badge(tester), ['2']);
  });
}
