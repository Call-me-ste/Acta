import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/item_form.dart';
import 'package:planner/ui/mobile/item_sheet.dart';

import '../../support/theme_providers.dart';

/// Il form unificato: un solo foglio per eventi e todo, con il selettore che
/// **non perde niente** quando si cambia tipo — è la ragione per cui esiste.
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

  Future<void> pumpForm(
    WidgetTester tester, {
    ItemType type = ItemType.evento,
    Event? event,
    Todo? todo,
  }) async {
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
                type: type,
                day: DateTime(2026, 9, 14),
                event: event,
                todo: todo),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('rinominare un evento conserva la fine del giorno seguente',
      (tester) async {
    final start = DateTime(2026, 9, 14, 23, 30, 9);
    final end = DateTime(2026, 9, 15, 1, 15, 12);
    await events.addEvent(title: 'Prima', start: start, end: end);
    await pumpForm(tester, event: events.events.single);
    await tester.enterText(find.widgetWithText(TextField, 'Titolo'), 'Dopo');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    final saved = events.events.single;
    expect(saved.title, 'Dopo');
    expect(saved.start, start);
    expect(saved.end, end);
  });

  testWidgets('cambiare tipo non perde quello che si è scritto',
      (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Titolo'),
      'Palestra',
    );
    expect(find.text('Inizio'), findsOneWidget);

    await tester.tap(find.text('To do'));
    await tester.pumpAndSettle();

    // La parte specifica cambia…
    // (Il controllo è su «Tutto il giorno» e non su «Inizio»: da quando anche un
    // todo ha i suoi orari, quella parola c'è in tutte e due le sezioni, ed è
    // giusto così.)
    expect(find.text('Tutto il giorno'), findsNothing);
    expect(find.text('Priorità'), findsOneWidget);
    // …ma il titolo è ancora lì.
    expect(find.text('Palestra'), findsOneWidget);

    // E tornando indietro si ritrova anche la parte evento.
    await tester.tap(find.text('Evento'));
    await tester.pumpAndSettle();
    expect(find.text('Tutto il giorno'), findsOneWidget);
    expect(find.text('Palestra'), findsOneWidget);
  });

  testWidgets('in creazione un todo prende la scadenza del giorno scelto',
      (tester) async {
    await pumpForm(tester, type: ItemType.todo);

    await tester.enterText(
        find.widgetWithText(TextField, 'Titolo'), 'Bolletta');
    // «Salva» sta in fondo al form: prima lo si porta in vista (e serve un pump
    // prima di misurare, altrimenti ensureVisible legge una geometria vecchia).
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salva'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    final todo = todos.todos.single;
    expect(todo.title, 'Bolletta');
    expect(todo.dueDate, DateTime(2026, 9, 14));
  });

  testWidgets('Indietro salva solo le nuove voci con un titolo',
      (tester) async {
    final giorno = DateTime(2026, 9, 14);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ...themeProviders(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => showItemForm(context,
                          type: ItemType.evento, day: giorno),
                      child: const Text('Apri form'),
                    )),
          ),
        ),
      ),
    );

    Future<void> apri() async {
      await tester.tap(find.text('Apri form'));
      await tester.pumpAndSettle();
    }

    await apri();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(events.events, isEmpty);

    await apri();
    await tester.enterText(find.byType(TextField).first, 'Pranzo');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Salva'), findsNothing);
    expect(events.events.single.title, 'Pranzo');
    expect(events.events.single.start, DateTime(2026, 9, 14, 9));
    expect(events.events.single.end, DateTime(2026, 9, 14, 10));

    await apri();
    await tester.tap(find.text('To do'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Bolletta');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(todos.todos.single.dueDate, giorno);

    await apri();
    await tester.enterText(find.byType(TextField).first, 'Da scartare');
    await tester.tap(find.byKey(const ValueKey('chiudi-form')));
    await tester.pumpAndSettle();
    expect(events.events, hasLength(1));
  });

  testWidgets('modificando, il selettore sparisce e compare Elimina',
      (tester) async {
    await todos.addTodo(title: 'Vecchio');
    final todo = todos.todos.single;

    await pumpForm(tester, type: ItemType.todo, todo: todo);

    // Cambiare tipo a un elemento esistente sarebbe una conversione, non una
    // modifica: il selettore non c'è.
    expect(find.text('Evento'), findsNothing);
    expect(find.text('Modifica'), findsOneWidget);
    expect(find.text('Elimina'), findsOneWidget);
  });
}
