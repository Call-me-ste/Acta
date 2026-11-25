import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';

/// La vista giorno deve **dire che giorno sta mostrando**: era l'unica delle tre a
/// non scriverlo da nessuna parte, e si capiva il giorno solo dalla posizione dello
/// scorrimento. La forma e' quella delle altre due: frecce ai lati, titolo in mezzo.
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

  Future<void> apriGiorno(WidgetTester tester, DateTime giorno) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(harness(giorno));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();
  }

  testWidgets('la vista giorno scrive la data che sta guardando',
      (tester) async {
    // Il 14 settembre 2026 e' un lunedi'.
    await apriGiorno(tester, DateTime(2026, 9, 14));
    expect(find.text('Lunedì 14 settembre'), findsOneWidget);
  });

  testWidgets('le freccette cambiano giorno e la data segue', (tester) async {
    await apriGiorno(tester, DateTime(2026, 9, 14));

    await tester.tap(find.byTooltip('Giorno successivo'));
    await tester.pumpAndSettle();
    expect(find.text('Martedì 15 settembre'), findsOneWidget);

    await tester.tap(find.byTooltip('Giorno precedente'));
    await tester.pumpAndSettle();
    expect(find.text('Lunedì 14 settembre'), findsOneWidget);
  });

  // L'elenco delle settimane aperto dalla data della vista giorno e' provato in
  // `calendar_navigation_test.dart`: li' la prova parla di navigazione, qui solo
  // di intestazione.
}
