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

/// Il cambio mese dalle **frecce** (e dall'elenco mese/anno) si anima come quello
/// col dito.
///
/// Prima era un salto secco: il mese cambiava nelle preferenze, la pagina nuova
/// era gia' quella centrale e non c'era niente da muovere. Ora il mese nuovo entra
/// dal lato da cui viene — quello dopo da destra, quello prima da sinistra.
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

  DateTime meseGuardato(WidgetTester tester) => tester
      .widget<MonthView>(find.byType(MonthView, skipOffstage: false))
      .focusedDay;

  /// Dove sta la griglia di un mese: quella che si sta guardando deve **muoversi**
  /// se c'e' un'animazione in corso (la chiave della pagina e' il suo mese).
  double sinistraDellaGriglia(WidgetTester tester, DateTime mese) => tester
      .getRect(find.byKey(ValueKey('mese-${mese.year}-${mese.month}')))
      .left;

  testWidgets('la freccia avanti fa entrare il mese, non lo fa saltare',
      (tester) async {
    await apri(tester);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(
      tester.binding.transientCallbackCount,
      greaterThan(0),
      reason: 'il mese nuovo deve entrare scorrendo, non comparire di colpo',
    );

    // A meta' animazione la pagina del mese nuovo non e' ancora a posto.
    await tester.pump(const Duration(milliseconds: 60));
    final aMeta = sinistraDellaGriglia(tester, DateTime(2026, 10));
    expect(aMeta, greaterThan(0), reason: 'sta entrando da destra');

    await tester.pumpAndSettle();
    expect(sinistraDellaGriglia(tester, DateTime(2026, 10)), 0);
    final mese = meseGuardato(tester);
    expect([mese.year, mese.month], [2026, 10]);
  });

  testWidgets('la freccia indietro fa entrare il mese da sinistra',
      (tester) async {
    await apri(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 60));
    final aMeta = sinistraDellaGriglia(tester, DateTime(2026, 8));
    expect(aMeta, lessThan(0), reason: 'sta entrando da sinistra');

    await tester.pumpAndSettle();
    expect(sinistraDellaGriglia(tester, DateTime(2026, 8)), 0);
    final mese = meseGuardato(tester);
    expect([mese.year, mese.month], [2026, 8]);
  });
}
