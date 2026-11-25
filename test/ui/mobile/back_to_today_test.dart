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

/// Il comando «Torna a oggi»: c'e' **solo** quando serve, e il tocco riporta il
/// giorno scelto e la griglia a oggi.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Widget harness(DateTime giorno) => MultiProvider(
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
        child: MaterialApp(home: CalendarPage(initialDay: giorno)),
      );

  Future<void> apri(WidgetTester tester, DateTime giorno) async {
    // Tela alta: due pulsanti in fondo alla pagina devono starci.
    await tester.binding.setSurfaceSize(const Size(420, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(harness(giorno));
    await tester.pumpAndSettle();
  }

  DateTime giornoScelto(WidgetTester tester) => tester
      .widget<MonthView>(find.byType(MonthView, skipOffstage: false))
      .selectedDay;

  testWidgets('guardando oggi il comando non c\'e\'', (tester) async {
    await apri(tester, DateTime.now());
    expect(find.byTooltip('Torna a oggi'), findsNothing);
  });

  testWidgets('con un altro giorno scelto il comando c\'e\' e riporta a oggi',
      (tester) async {
    final treGiorniFa = DateTime.now().subtract(const Duration(days: 3));
    await apri(tester, treGiorniFa);

    expect(
      find.byTooltip('Torna a oggi'),
      findsOneWidget,
      reason: 'il giorno scelto non e\' oggi',
    );

    await tester.tap(find.byTooltip('Torna a oggi'));
    await tester.pumpAndSettle();

    final oggi = DateTime.now();
    expect(
      find.byTooltip('Torna a oggi'),
      findsNothing,
      reason: 'tornati a oggi, il comando non serve piu\'',
    );
    final scelto = giornoScelto(tester);
    expect(
      (scelto.year, scelto.month, scelto.day),
      (oggi.year, oggi.month, oggi.day),
    );
  });

  testWidgets('anche guardando un altro mese compare', (tester) async {
    // Oggi selezionato, ma la griglia su un altro mese: il comando c'e' lo stesso.
    await apri(tester, DateTime.now());
    await tester.tap(find.byTooltip('Mese successivo'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Torna a oggi'), findsOneWidget);
  });
}
