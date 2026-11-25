import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/ui/mobile/item_form.dart';
import 'package:planner/ui/mobile/item_sheet.dart';
import 'package:planner/ui/shared/top_inset.dart';

import '../../support/theme_providers.dart';

/// Il contenuto non deve finire sotto le **notifiche del telefono**.
///
/// La regola e' una sola (`topInset`) e la applicano i fogli: le pagine con la
/// `AppBar` ricevono gia' quello spazio dalla barra, i fogli no — ed e' li' che
/// il titolo "Nuovo" finiva appiccicato all'orologio (visto sul telefono).
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  testWidgets('topInset somma la barra di stato e il respiro', (tester) async {
    late double valore;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 37)),
        child: Builder(
          builder: (context) {
            valore = topInset(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(valore, 37 + AppSpacing.l);
  });

  testWidgets('il foglio del form lascia la barra di stato piu\' il respiro',
      (tester) async {
    const barraDiStato = 40.0;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: barraDiStato);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: db),
          ChangeNotifierProvider<EventProvider>.value(value: EventProvider(db)),
          ChangeNotifierProvider<TodoProvider>.value(value: TodoProvider(db)),
          ...themeProviders(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showItemForm(
                  context,
                  type: ItemType.todo,
                  day: DateTime(2026, 9, 14),
                ),
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    // Il foglio avvolge il form in un Padding: e' quello che tiene le scritte
    // fuori dalla zona delle notifiche.
    //
    // Lo spazio della barra di stato si legge **da chi apre il foglio**: dentro,
    // il framework toglie quel padding dall'albero e vale zero. E' il motivo per
    // cui il titolo "Nuovo" finiva sotto l'orologio (visto sul telefono).
    final contenitore = tester.widget<Padding>(
      find
          .ancestor(of: find.byType(ItemForm), matching: find.byType(Padding))
          .first,
    );
    final sopra = (contenitore.padding as EdgeInsets).top;

    expect(sopra, barraDiStato + AppSpacing.l);
  });
}
