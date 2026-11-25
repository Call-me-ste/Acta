import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/month_view.dart';
import '../../support/grid.dart';

/// La griglia del mese torna **in cima** quando cambia il giorno o il mese.
///
/// Il difetto: scegliendo un giorno di un altro mese (o saltando con l'elenco),
/// la pagina restava scorsa dov'era, quindi le celle di quel giorno potevano
/// finire fuori vista. Ma **scorrere restando sullo stesso giorno non deve
/// muovere niente**: chi scorre sta leggendo.
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
          ChangeNotifierProvider.value(
            value: AppSettingsController(db.settings)..load(),
          ),
          ChangeNotifierProvider.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
        ],
        child: MaterialApp(
          home: CalendarPage(initialDay: DateTime(2026, 9, 14)),
        ),
      );

  /// L'offset della pagina del mese (lo `CustomScrollView` della vista mese).
  double offset(WidgetTester tester) {
    final vista = find.descendant(
      of: find.byType(MonthView, skipOffstage: false),
      matching: find.byType(Scrollable),
    );
    return tester.state<ScrollableState>(vista.first).position.pixels;
  }

  Future<void> apri(WidgetTester tester) async {
    // Tela piu' bassa del contenuto: cosi' c'e' davvero qualcosa da scorrere.
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
  }

  testWidgets(
      'scorrere il mese e poi cambiare giorno riporta la griglia in cima',
      (tester) async {
    await apri(tester);

    // Si scorre in giu' (la griglia sale).
    await tester.drag(
      find.byType(MonthView, skipOffstage: false),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(offset(tester), greaterThan(0), reason: 'la pagina si e\' mossa');

    // Un giorno della griglia (il 21): cambiando giorno le celle di quel giorno
    // si devono vedere per intero, quindi la pagina torna in cima.
    await toccaGiorno(tester, DateTime(2026, 9, 21));
    await tester.pumpAndSettle();

    expect(
      offset(tester),
      0,
      reason: 'cambiando giorno la griglia torna in cima: le celle si vedono',
    );
  });

  testWidgets('tornando a oggi con il comando, la griglia torna in cima',
      (tester) async {
    await apri(tester);
    // Si va in un altro mese e si scorre in giu'.
    await tester.binding.setSurfaceSize(const Size(400, 700));
    await tester.drag(
      find.byType(MonthView, skipOffstage: false),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(offset(tester), greaterThan(0));

    // Il comando "torna a oggi" e' un pulsante fuori dalla pagina: resta visibile
    // anche con la pagina scorsa. E' il caso reale: sei lontano, torni, e vuoi
    // vedere le celle di oggi.
    await tester.tap(find.byTooltip('Torna a oggi'));
    await tester.pumpAndSettle();

    expect(
      offset(tester),
      0,
      reason: 'tornando a oggi la griglia si vede dal principio',
    );
  });

  testWidgets('scorrere senza cambiare giorno non muove niente',
      (tester) async {
    await apri(tester);

    await tester.drag(
      find.byType(MonthView, skipOffstage: false),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final prima = offset(tester);
    expect(prima, greaterThan(0));

    // Un giro in settimana e ritorno: il giorno non cambia, quindi la posizione
    // resta quella (e' il comportamento voluto).
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mese'));
    await tester.pumpAndSettle();

    expect(offset(tester), prima,
        reason: 'chi scorre sta leggendo: non si tocca');
  });
}
