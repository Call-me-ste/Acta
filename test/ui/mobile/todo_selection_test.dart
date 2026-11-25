import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_selection.dart';
import 'package:planner/ui/mobile/todo_page.dart';

import '../../support/theme_providers.dart';

/// La **selezione multipla** dei todo (#90): si entra col tocco prolungato, si
/// sceglie col tocco, si esce con la X (o col tasto indietro, che e' del guscio:
/// vedi `back_button_test.dart`), e le quattro azioni valgono per **tutti** gli
/// scelti in una modifica sola.
void main() {
  late DatabaseService db;
  late TodoProvider provider;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    provider = TodoProvider(db);
  });

  tearDown(() => db.close());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TodoProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => SelezioneDeiTodo()),
          ...themeProviders(db),
        ],
        child: const MaterialApp(home: TodoPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('il tocco prolungato apre la selezione, il tocco sceglie',
      (tester) async {
    await provider.addTodo(title: 'Uno');
    await provider.addTodo(title: 'Due');
    await pumpPage(tester);

    // Chiusa: la barra non c'e'.
    expect(find.byKey(const ValueKey('chiudi-selezione')), findsNothing);

    await tester.longPress(find.text('Uno'));
    await tester.pumpAndSettle();
    expect(find.text('1 selezionati'), findsOneWidget);

    await tester.tap(find.text('Due'));
    await tester.pumpAndSettle();
    expect(find.text('2 selezionati'), findsOneWidget);

    // Il tocco e' un interruttore: toccarlo di nuovo lo toglie.
    await tester.tap(find.text('Due'));
    await tester.pumpAndSettle();
    expect(find.text('1 selezionati'), findsOneWidget);
  });

  testWidgets('seleziona tutti prende quelli che si vedono', (tester) async {
    await provider.addTodo(title: 'Uno');
    await provider.addTodo(title: 'Due');
    await provider.addTodo(title: 'Tre');
    await pumpPage(tester);

    await tester.longPress(find.text('Uno'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seleziona-tutti')));
    await tester.pumpAndSettle();

    expect(find.text('3 selezionati'), findsOneWidget);
  });

  testWidgets('spuntare molti: una modifica sola, e tutti fatti',
      (tester) async {
    await provider.addTodo(title: 'Uno');
    await provider.addTodo(title: 'Due');
    await pumpPage(tester);

    await tester.longPress(find.text('Uno'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seleziona-tutti')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spunta-selezione')));
    await tester.pumpAndSettle();

    expect(provider.todos.every((todo) => todo.completed), isTrue);
    expect(db.getTodos().map((row) => row['version']), everyElement(2),
        reason: 'ogni riga ha la sua versione: le scritture restano separate');
    // La selezione si chiude da sola dopo l'azione.
    expect(find.byKey(const ValueKey('chiudi-selezione')), findsNothing);
    expect(find.text('Annulla'), findsOneWidget);
  });

  testWidgets('spostare la data di molti', (tester) async {
    await provider.addTodo(title: 'Uno');
    await provider.addTodo(title: 'Due');
    await pumpPage(tester);

    await tester.longPress(find.text('Uno'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seleziona-tutti')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sposta-selezione')));
    await tester.pumpAndSettle();

    // Il calendario si apre sulla data di oggi: «OK» prende quella.
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final oggi = DateTime.now();
    final atteso = DateTime(oggi.year, oggi.month, oggi.day);
    expect(provider.todos.every((todo) => todo.dueDate == atteso), isTrue);
  });

  testWidgets('cambiare categoria di molti', (tester) async {
    final studio = await CategoryController(db).create(name: 'Studio');
    await provider.addTodo(title: 'Uno');
    await provider.addTodo(title: 'Due');
    await pumpPage(tester);

    await tester.longPress(find.text('Uno'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seleziona-tutti')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('categoria-selezione')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('categoria-${studio.id}')));
    await tester.pumpAndSettle();

    expect(
      provider.todos.every((todo) => todo.categoryIds.contains(studio.id)),
      isTrue,
    );
  });

  testWidgets('la X chiude la selezione e non tocca i todo', (tester) async {
    await provider.addTodo(title: 'Uno');
    await pumpPage(tester);

    await tester.longPress(find.text('Uno'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chiudi-selezione')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chiudi-selezione')), findsNothing);
    expect(provider.todos.single.completed, isFalse);
    expect(provider.todos.single.title, 'Uno');
  });
}
