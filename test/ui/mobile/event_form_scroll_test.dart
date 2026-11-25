import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/ui/mobile/item_sheet.dart';

import '../../support/theme_providers.dart';

/// Il form evento deve **scorrere**: con `isScrollControlled` il drag di
/// chiusura del foglio rubava il gesto e il contenuto restava fermo (segnalato
/// dall'utente e riprodotto sul device). Questo test fallisce se il gesto torna
/// a essere mangiato dal foglio.
void main() {
  late DatabaseService db;
  late EventProvider events;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
  });

  tearDown(() => db.close());

  testWidgets('il form evento si scorre con la tastiera aperta',
      (tester) async {
    // Viewport da telefono con i campi del nuovo evento.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ...themeProviders(db),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
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
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    // **Il caso che l'utente vede**: tastiera aperta. L'emulatore dell'ambiente
    // ha la tastiera hardware, quindi la soft keyboard non compare mai: senza
    // questo inset il form entra tutto nello schermo e non c'è niente da
    // scorrere (e il test non proverebbe nulla).
    tester.view.viewInsets = const FakeViewPadding(bottom: 1000);
    await tester.pumpAndSettle();

    final campo = find.text('Titolo');
    final prima = tester.getRect(campo);
    final salva = find.text('Salva');
    final posizioneSalva = tester.getRect(salva);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();

    final dopo = tester.getRect(campo);
    expect(tester.getRect(salva), posizioneSalva);

    expect(
      dopo.top,
      lessThan(prima.top),
      reason: 'il contenuto non si è mosso: il gesto è stato preso dal foglio',
    );
  });
}
