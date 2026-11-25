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

/// Le celle del mese devono **rispondere** al tocco.
///
/// La recensione l'aveva segnato: il numero del giorno scelto diventa un cerchio
/// pieno *dopo* il tocco, ma finche' il dito e' giu' non succede niente — nessuna
/// tinta, nessuna increspatura. Per una griglia che si tocca tutto il giorno, si
/// legge come «non risponde».
///
/// La cella ora e' un `InkWell` (tinta sotto il dito) su un `Material` trasparente,
/// e i due gesti restano quelli di prima: tocco = seleziona, tocco prolungato =
/// apri il giorno.
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

  testWidgets('la cella risponde al tocco: la tinta compare sotto il dito',
      (tester) async {
    await apri(tester);
    final mese = DateTime(2026, 9);
    expect(
      disegnoDellaGriglia(tester, mese).premuto,
      isNull,
      reason: 'a riposo non c\'è nessuna tinta',
    );

    // Il dito giù **e fermo**: la tinta deve comparire subito, non dopo il
    // rilascio. È la differenza che la recensione aveva segnato.
    final gesto = await tester.startGesture(
      cellaDelGiorno(tester, DateTime(2026, 9, 16)).center,
    );
    await tester.pump();

    expect(
      disegnoDellaGriglia(tester, mese).premuto,
      isNotNull,
      reason: 'la cella deve dare la tinta al tocco, non solo cambiare dopo',
    );

    await gesto.up();
    await tester.pumpAndSettle();
    expect(disegnoDellaGriglia(tester, mese).premuto, isNull);
  });

  testWidgets('il tocco seleziona e il tocco prolungato apre il giorno',
      (tester) async {
    await apri(tester);

    await toccaGiorno(tester, DateTime(2026, 9, 16));
    await tester.pumpAndSettle();
    // I campi del calendario, non l'istante: `table_calendar` consegna i giorni in
    // UTC, e confrontare gli istanti farebbe litigare due mezzanotti dello stesso
    // giorno.
    final scelto = tester
        .widget<MonthView>(find.byType(MonthView, skipOffstage: false))
        .selectedDay;
    expect(
      [scelto.year, scelto.month, scelto.day],
      [2026, 9, 16],
      reason: 'il tocco deve selezionare il giorno',
    );

    await tieniPremutoIlGiorno(tester, DateTime(2026, 9, 16));
    await tester.pumpAndSettle();
    expect(
      find.text('Mercoledì 16 settembre'),
      findsOneWidget,
      reason: 'il tocco prolungato deve aprire quel giorno nella vista giorno',
    );
  });
}
