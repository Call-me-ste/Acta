import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/palette/domain/tono.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/ui/mobile/colore_sheet.dart';

void main() {
  testWidgets('il foglio offre i toni e applica quello scelto', (tester) async {
    final db = DatabaseService();
    await db.init(dbPath: ':memory:');
    addTearDown(db.close);

    final settings = AppSettingsController(db.settings)..load();
    final palettes = PaletteController(db)
      ..load()
      ..allineaPresets();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: palettes),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showColoreSheet(context),
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.text('Tono'), findsOneWidget);
    expect(find.text('Naturale'), findsOneWidget);
    expect(find.text('Tinte morbide e chiare'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tono-pastello')));
    await tester.pumpAndSettle();

    expect(palettes.tono, TonoTema.pastello);
    expect(find.text('Tinte morbide e chiare'), findsOneWidget);
  });
}
