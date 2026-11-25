import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/ui/mobile/item_form.dart';
import 'package:planner/ui/mobile/item_sheet.dart';

import '../../support/theme_providers.dart';

/// La **prima** apertura del form in una sessione non si anima.
///
/// È l'unica che paga la prima rasterizzazione del contenuto del foglio:
/// misurato sul telefono con l'agenda di prova, 11,8 ms di build + **22,1 ms di
/// raster**, contro 7-12 + 4 delle aperture successive. Con un'animazione quella
/// spesa si vede — il foglio si ferma mentre sale — e senza animazione diventa
/// un fotogramma di attesa. Il compromesso è quello chiesto: attendere un
/// istante, non vedere il foglio tremare.
///
/// Il caso «prima» vale una volta per processo: questa e' l'unica apertura di
/// questo file, ed e' quello che il test deve verificare.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  /// La durata dell'apertura, letta dalla rotta del foglio montato.
  Duration? durataDelFoglio(WidgetTester tester) {
    final context = tester.element(find.byType(ItemForm));
    final route = ModalRoute.of(context)! as ModalBottomSheetRoute;
    return route.sheetAnimationStyle?.duration;
  }

  Future<void> pumpLauncher(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
          ...themeProviders(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showItemForm(
                  context,
                  type: ItemType.evento,
                  day: DateTime(2026, 9, 14),
                ),
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('la prima apertura non si anima, la seconda sì', (tester) async {
    await pumpLauncher(tester);

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemForm), findsOneWidget);
    expect(
      durataDelFoglio(tester),
      Duration.zero,
      reason: 'la prima apertura paga la prima rasterizzazione del contenuto: '
          'un fotogramma di attesa al posto di uno scatto mentre il foglio sale',
    );

    // Chiudere e riaprire: la seconda non ha piu' niente di freddo da pagare,
    // quindi il foglio torna a salire come tutti gli altri.
    Navigator.of(tester.element(find.byType(ItemForm))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ItemForm), findsNothing);

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    expect(durataDelFoglio(tester), AppMotion.slow);
  });
}
