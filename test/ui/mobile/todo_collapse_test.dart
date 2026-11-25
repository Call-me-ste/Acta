import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_selection.dart';
import 'package:planner/ui/mobile/row_collapse.dart';
import 'package:planner/ui/mobile/todo_page.dart';

import '../../support/theme_providers.dart';

/// La chiusura di «Scaduti» e «Completati»: la **parola** che dice cosa succede,
/// e l'animazione che evita il salto.
///
/// Il test controlla anche il **mezzo** dell'animazione, non solo la fine: subito
/// dopo il tocco le prime righe sono ancora nell'albero dentro una
/// `RigaCheSiChiude`, e spariscono quando l'animazione è finita. Se qualcuno
/// togliesse l'animazione, il primo controllo diventerebbe rosso.
void main() {
  late DatabaseService db;
  late TodoProvider todos;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  List<SingleChildWidget> providers() => [
        ChangeNotifierProvider.value(value: todos),
        ChangeNotifierProvider(create: (_) => SelezioneDeiTodo()),
        ChangeNotifierProvider(create: (_) => EventProvider(db)),
        ...themeProviders(db),
      ];

  Future<void> pumpPage(WidgetTester tester) async {
    // Le righe si costruiscono solo se entrano nello schermo: 800x600 non basta
    // per tre righe piu' le intestazioni.
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: providers(),
        child: const MaterialApp(home: TodoPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la parola dice «nascondi» quando è aperta e «mostra» quando è chiusa',
      (tester) async {
    for (final titolo in ['Uno', 'Due', 'Tre']) {
      await todos.addTodo(title: titolo, dueDate: DateTime(2026, 9, 10));
    }
    await pumpPage(tester);

    // **Chiusa di partenza**: la parola dice «mostra». Solo la fascia degli
    // scaduti: i completati non ci sono.
    expect(find.text('Mostra'), findsOneWidget);
    expect(find.text('Nascondi'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('intestazione-Scaduti')));
    await tester.pumpAndSettle();

    // Aperta: «nascondi».
    expect(find.text('Nascondi'), findsOneWidget);
    expect(find.text('Mostra'), findsNothing);
  });

  testWidgets('chiudendola le righe si animano e poi se ne vanno',
      (tester) async {
    for (final titolo in ['Uno', 'Due', 'Tre']) {
      await todos.addTodo(title: titolo, dueDate: DateTime(2026, 9, 10));
    }
    await pumpPage(tester);

    // Chiusa di partenza: la si apre, e le tre righe entrano.
    expect(find.text('Uno'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('intestazione-Scaduti')));
    await tester.pumpAndSettle();
    expect(find.text('Uno'), findsOneWidget);

    // Poi si chiude: le righe si animano e se ne vanno.
    await tester.tap(find.byKey(const ValueKey('intestazione-Scaduti')));
    await tester.pump();

    // A metà strada: le righe sono ancora lì, dentro l'animazione.
    expect(
      find.byType(RigaCheSiChiude),
      findsNWidgets(3),
      reason: 'le righe visibili si chiudono, non spariscono di colpo',
    );

    await tester.pumpAndSettle();

    // Finite: la lista si è rifatta senza di loro.
    expect(find.byType(RigaCheSiChiude), findsNothing);
    expect(find.text('Uno'), findsNothing);
    expect(find.text('Due'), findsNothing);
    expect(find.text('Tre'), findsNothing);
  });
}
