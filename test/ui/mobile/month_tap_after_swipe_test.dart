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

/// **Il tocco arriva anche subito dopo uno scorrimento.**
///
/// È la segnalazione dell'utente: «quando scorri al mese dopo, se tocchi un
/// giorno velocemente non legge il tocco». La causa era il riconoscitore del
/// tocco: viveva dentro la cella, e la cella veniva ricostruita proprio mentre il
/// dito era giù (un cambio mese ricostruiva 62 celle). Adesso il tocco lo prende
/// **un solo strato** che copre la griglia, e le pagine dei mesi hanno una chiave
/// stabile: l'elemento che riceve il tocco non viene rifatto sotto il dito.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Future<void> apri(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
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
      ),
    );
    await tester.pumpAndSettle();
  }

  DateTime selezionato(WidgetTester tester) => tester
      .widget<MonthView>(find.byType(MonthView, skipOffstage: false))
      .selectedDay;

  testWidgets(
      'toccando un giorno mentre il mese si sta assestando, il giorno '
      'si seleziona lo stesso', (tester) async {
    await apri(tester);

    // Si scorre al mese successivo e si tocca **mentre l'assestamento e' in
    // corso**: e' il gesto reale — chi scorre e vede il mese nuovo tocca subito.
    await tester.drag(
      grigliaDelMese(DateTime(2026, 9)),
      const Offset(-260, 0),
    );
    await tester.pump(const Duration(milliseconds: 80));

    await toccaGiorno(tester, DateTime(2026, 10, 12));
    await tester.pumpAndSettle();

    final scelto = selezionato(tester);
    expect(
      [scelto.year, scelto.month, scelto.day],
      [2026, 10, 12],
      reason: 'il tocco subito dopo lo scorrimento deve arrivare al giorno',
    );
  });

  testWidgets('e il tocco cade sul giorno giusto, non su quello accanto',
      (tester) async {
    await apri(tester);

    // Due giorni vicini, uno per volta: se la geometria sbagliasse di una cella,
    // il primo dei due lo direbbe.
    await toccaGiorno(tester, DateTime(2026, 9, 9));
    await tester.pumpAndSettle();
    var scelto = selezionato(tester);
    expect([scelto.month, scelto.day], [9, 9]);

    await toccaGiorno(tester, DateTime(2026, 9, 17));
    await tester.pumpAndSettle();
    scelto = selezionato(tester);
    expect([scelto.month, scelto.day], [9, 17]);
  });
}
