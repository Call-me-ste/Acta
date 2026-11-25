import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/ui/mobile/item_sheet.dart';

import '../../support/theme_providers.dart';

/// Il colore di un evento si sceglie in due modi: dalla palette attiva, oppure
/// scritto a mano. Entrambi devono arrivare **nel database**, non solo
/// nell'anteprima del form.
void main() {
  late DatabaseService db;
  late EventProvider events;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
  });

  tearDown(() => db.close());

  Future<void> openForm(WidgetTester tester) async {
    // Viewport da telefono: il form è più alto dei 600 px di default e senza
    // questo "Salva" finisce fuori schermo (il tap mancherebbe il bersaglio).
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
  }

  /// Il form è dentro un foglio che si scorre: come l'utente, prima si porta il
  /// bersaglio in vista e poi si tocca.
  Future<void> tapInForm(WidgetTester tester, Finder finder) async {
    // ensureVisible legge la geometria del frame corrente: se arriva subito
    // dopo un enterText (o un altro cambiamento) senza pump, misura coordinate
    // stantie e lo scroll non parte — diagnosticato con una sonda: Salva restava
    // a y=932 invece di salire a 750.
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSave(WidgetTester tester) async {
    // Il primo TextField del form è il titolo (nel dialog del colore ce n'è
    // uno, ma il dialog è chiuso in questo momento).
    await tester.enterText(find.byType(TextField).first, 'Palestra');
    await tapInForm(tester, find.text('Salva'));
  }

  /// Il colore vive in un foglio: si apre dalla riga e si conferma con «Fatto».
  Future<void> apriColore(WidgetTester tester) async {
    await tapInForm(tester, find.text('Colore'));
  }

  Future<void> chiudiColore(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Fatto'));
    await tester.pumpAndSettle();
  }

  testWidgets('il colore scelto dalla palette finisce nell\'evento',
      (tester) async {
    await openForm(tester);

    await apriColore(tester);
    await tester.tap(find.byKey(const ValueKey('event-color-2')));
    await tester.pumpAndSettle();
    await chiudiColore(tester);
    await fillAndSave(tester);

    final stored = db.getEvents().map(Event.fromRow).single;
    expect(stored.title, 'Palestra');
    expect(stored.colorIndex, 2);
    expect(stored.colorHex, isNull);
  });

  testWidgets('un colore scelto dal selettore vince sulla palette',
      (tester) async {
    await openForm(tester);

    await apriColore(tester);
    // Prima un colore della palette, poi quello personalizzato: il secondo
    // deve sostituire il primo, non conviverci.
    await tester.tap(find.byKey(const ValueKey('event-color-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-color-custom')));
    await tester.pumpAndSettle();

    // Il campo del codice non c'e' piu' (passo 12): nel selettore si sceglie
    // dalla ruota o dai colori pronti che ha dentro.
    final pronto = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byKey(const ValueKey('pronto-#e57373')),
    );
    await tester.tap(pronto);
    await tester.pump();
    await tester.tap(find.text('Usa questo'));
    await tester.pumpAndSettle();
    await chiudiColore(tester);

    await fillAndSave(tester);

    final stored = db.getEvents().map(Event.fromRow).single;
    expect(stored.colorHex, '#e57373');
  });

  testWidgets(
      'scegliere un colore della palette dopo uno personalizzato lo toglie',
      (tester) async {
    await openForm(tester);

    await apriColore(tester);
    await tester.tap(find.byKey(const ValueKey('event-color-custom')));
    await tester.pumpAndSettle();
    // Il campo del codice non c'e' piu' (passo 12): si sceglie dai colori pronti.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byKey(const ValueKey('pronto-#e57373')),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Usa questo'));
    await tester.pumpAndSettle();

    // Torna sulla palette: l'hex non deve restare a vincere in silenzio.
    await tester.tap(find.byKey(const ValueKey('event-color-3')));
    await tester.pumpAndSettle();
    await chiudiColore(tester);
    await fillAndSave(tester);

    final stored = db.getEvents().map(Event.fromRow).single;
    expect(stored.colorHex, isNull);
    expect(stored.colorIndex, 3);
  });
}
