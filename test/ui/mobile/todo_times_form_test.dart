import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/item_form.dart';
import 'package:planner/ui/mobile/item_type.dart';

import '../../support/theme_providers.dart';

/// Gli **orari di un todo** nel form: solo inizio, solo fine, entrambi o nessuno,
/// e la regola che li lega alla scadenza (un'ora senza giorno non vuol dire
/// niente).
void main() {
  late DatabaseService db;
  late EventProvider events;
  late TodoProvider todos;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  Future<void> pumpForm(WidgetTester tester, {Todo? todo}) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ...themeProviders(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ItemForm(
              type: ItemType.todo,
              day: DateTime(2026, 9, 14),
              todo: todo,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Sceglie un'ora dal selettore: si tocca la riga e poi «OK», che conferma
  /// l'ora proposta (le 08:00 per un todo senza orario).
  Future<void> scegliOra(WidgetTester tester, String etichetta) async {
    if (find.text(etichetta).evaluate().isEmpty) {
      await tester.tap(find.text('Orario'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(etichetta));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('gli orari ci sono solo con una scadenza', (tester) async {
    await pumpForm(tester);
    expect(find.text('Inizio'), findsNothing);
    await tester.tap(find.text('Orario'));
    await tester.pumpAndSettle();
    expect(find.text('Inizio'), findsOneWidget);
    expect(find.text('Fine'), findsOneWidget);
    // Nessun orario scelto: nessuna riga di riepilogo. (Non si contano i
    // «Nessuno»: la parola compare anche per il colore del todo, e un test che
    // conta le parole è un test che si rompe per un motivo che non c'entra.)
    expect(find.textContaining('dalle '), findsNothing);
    expect(find.textContaining(' - '), findsNothing);

    await tester.tap(find.text('Rimuovi scadenza'));
    await tester.pumpAndSettle();

    // Senza giorno non c'è niente da scegliere.
    expect(find.text('Inizio'), findsNothing);
    expect(find.text('Fine'), findsNothing);
  });

  testWidgets("l'inizio da solo, poi anche la fine", (tester) async {
    await pumpForm(tester);
    expect(find.byKey(const ValueKey('rimuovi-orario')), findsNothing);

    await scegliOra(tester, 'Inizio');
    expect(find.textContaining('dalle '), findsOneWidget);
    expect(find.byKey(const ValueKey('rimuovi-orario')), findsOneWidget);

    await scegliOra(tester, 'Fine');
    expect(find.textContaining('dalle '), findsNothing);
    expect(find.textContaining(' - '), findsOneWidget);
  });

  testWidgets("«Rimuovi orario» toglie l'orario e lascia il giorno",
      (tester) async {
    await pumpForm(tester);
    await scegliOra(tester, 'Inizio');

    await tester.tap(find.byKey(const ValueKey('rimuovi-orario')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rimuovi-orario')), findsNothing);
    expect(find.textContaining('dalle '), findsNothing);
    expect(find.textContaining(' - '), findsNothing);
    expect(find.text('Scadenza'), findsOneWidget);
    expect(find.text('Inizio'), findsOneWidget);
  });

  testWidgets('togliendo la scadenza se ne vanno anche gli orari, e si salva',
      (tester) async {
    // Il todo esiste già, come quando si tocca una riga dell'elenco: il
    // salvataggio è un **aggiornamento**, che è il percorso che ci interessa.
    await todos.addTodo(
      title: 'Bolletta',
      dueDate: DateTime(2026, 9, 14),
      startMinutes: 8 * 60,
      endMinutes: 9 * 60,
    );
    await pumpForm(tester, todo: todos.todos.single);
    expect(find.textContaining(' - '), findsOneWidget);

    await tester.tap(find.text('Rimuovi scadenza'));
    await tester.pumpAndSettle();

    // Il tasto sta in fondo a un form più alto dello schermo di prova (le due
    // righe orario lo hanno allungato): si porta in vista prima di toccarlo.
    await tester.ensureVisible(find.text('Salva'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    // La prova sta nel database: la regola vale per il percorso di salvataggio,
    // non solo per quello che si vede.
    final salvato = todos.todos.single;
    expect(salvato.dueDate, isNull);
    expect(salvato.startMinutes, isNull);
    expect(salvato.endMinutes, isNull);
    expect(salvato.title, 'Bolletta');
  });

  testWidgets('un todo con solo inizio si riapre con solo inizio',
      (tester) async {
    final todo = Todo(
      id: 't2',
      title: 'Palestra',
      dueDate: DateTime(2026, 9, 14),
      startMinutes: 18 * 60,
    );
    await pumpForm(tester, todo: todo);

    expect(find.textContaining('dalle '), findsOneWidget);
    expect(find.textContaining(' - '), findsNothing);
    expect(find.text('Fine'), findsOneWidget);
  });
}
