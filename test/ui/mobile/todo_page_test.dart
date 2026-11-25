import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_recurrence.dart';
import 'package:planner/ui/mobile/todo_header.dart';
import 'package:planner/ui/mobile/todo_page.dart';
import 'package:planner/ui/shared/filter_pill.dart';
import 'package:planner/ui/shared/priority_style.dart';
import 'package:planner/ui/shared/todo_check.dart';

import '../../support/theme_providers.dart';

/// La scheda Todo come la vede l'utente: aggiunta rapida, intestazione con la
/// vista, fascia degli scaduti sopra e dei completati sotto.
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
          // Colori, categorie e filtri: la scheda li legge tutti.
          ...themeProviders(db),
        ],
        child: const MaterialApp(home: TodoPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Sceglie una vista dal menu' dell'intestazione (un tocco, poi la voce).
  Future<void> scegliVista(WidgetTester tester, String nome) async {
    await tester.tap(find.byKey(const ValueKey('cambia-vista')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('vista-$nome')));
    await tester.pumpAndSettle();
  }

  testWidgets('il tap sul cerchio commuta senza eccezioni', (tester) async {
    await provider.addTodo(title: 'Spesa');
    await pumpPage(tester);

    expect(find.text('Spesa'), findsOneWidget);

    await tester.tap(find.byType(TodoCheck));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(provider.todos.single.completed, isTrue);
  });

  testWidgets('senza todo mostra lo stato vuoto', (tester) async {
    await pumpPage(tester);

    expect(find.text('Nessun To do'), findsOneWidget);
    expect(find.byType(TodoCheck), findsNothing);
  });

  testWidgets('la casella di aggiunta rapida è stata rimossa', (tester) async {
    await pumpPage(tester);

    expect(find.byKey(const ValueKey('aggiunta-rapida')), findsNothing);
    expect(find.byTooltip('Nuovo To do'), findsOneWidget);
  });

  testWidgets('priorità e scadenza sono visibili sulla riga', (tester) async {
    await provider.addTodo(
      title: 'Spesa',
      priority: 3,
      // Lontana di proposito: cosi' la riga mostra la data e non "Tra N
      // giorni", che dipenderebbe dal giorno in cui gira il test.
      dueDate: DateTime(2027, 5, 20),
    );
    await pumpPage(tester);

    // La priorità si legge dal **segno** (la barretta e' il colore): la parola
    // sta nel form, dove si sceglie.
    expect(find.byIcon(priorityIcon(3)), findsOneWidget);
    expect(find.text('20/5/2027'), findsOneWidget);
    // Niente parola "Urgente" su ogni riga: era una delle cose che rendevano
    // l'elenco rumoroso.
    expect(find.text('Urgente'), findsNothing);
  });

  testWidgets('la vista si cambia dal menu e l\'elenco segue', (tester) async {
    final oggi = DateTime.now();
    await provider.addTodo(title: 'Compito di oggi', dueDate: oggi);
    await provider.addTodo(
      title: 'Compito di domani',
      dueDate: oggi.add(const Duration(days: 1)),
    );
    await pumpPage(tester);

    expect(find.text('Compito di oggi'), findsOneWidget);
    expect(find.text('Compito di domani'), findsOneWidget);

    await scegliVista(tester, 'oggi');

    expect(find.text('Compito di oggi'), findsOneWidget);
    expect(find.text('Compito di domani'), findsNothing);
    // L'intestazione dice dove sei ("Oggi" e' anche sulla riga, come data).
    expect(find.text('Oggi'), findsWidgets);
  });

  testWidgets('una vista senza niente lo dice', (tester) async {
    await provider.addTodo(
      title: 'Compito di domani',
      dueDate: DateTime.now().add(const Duration(days: 1)),
    );
    await pumpPage(tester);

    await scegliVista(tester, 'oggi');

    expect(find.text('Nessun To do in questa vista'), findsOneWidget);
  });

  testWidgets('la fascia degli scaduti parte chiusa, si apre e si richiude',
      (tester) async {
    await provider.addTodo(
      title: 'Compito scaduto',
      dueDate: DateTime.now().subtract(const Duration(days: 3)),
    );
    await provider.addTodo(title: 'Compito di oggi', dueDate: DateTime.now());
    await pumpPage(tester);

    // **Chiusa di partenza** (il default): il conteggio c'è, le righe no —
    // gli scaduti sono una cosa da guardare apposta.
    expect(find.text('Scaduti (1)'), findsOneWidget);
    expect(find.text('Compito scaduto'), findsNothing);
    // La fascia non tocca l'elenco sotto.
    expect(find.text('Compito di oggi'), findsOneWidget);

    // Un tocco li apre.
    await tester.tap(find.byKey(const ValueKey('intestazione-Scaduti')));
    await tester.pumpAndSettle();
    expect(find.text('Compito scaduto'), findsOneWidget);

    // Un altro tocco richiude: resta il numero, le righe spariscono.
    await tester.tap(find.byKey(const ValueKey('intestazione-Scaduti')));
    await tester.pumpAndSettle();
    expect(find.text('Scaduti (1)'), findsOneWidget);
    expect(find.text('Compito scaduto'), findsNothing);
    expect(find.text('Compito di oggi'), findsOneWidget);

    // Vale in ogni vista del filtro: cambia vista, la fascia resta — chiusa.
    await scegliVista(tester, 'oggi');
    await tester.pumpAndSettle();
    expect(find.text('Scaduti (1)'), findsOneWidget);
    expect(find.text('Compito scaduto'), findsNothing);
  });

  testWidgets('i completati stanno in una fascia chiusa, in fondo',
      (tester) async {
    await provider.addTodo(title: 'Spesa');
    await provider.toggleTodo(provider.todos.single.id);
    await pumpPage(tester);

    // Chiusa di partenza: la storia non deve rubare spazio a cosa resta da fare.
    expect(find.text('Completati (1)'), findsOneWidget);
    expect(find.text('Spesa'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('intestazione-Completati')));
    await tester.pumpAndSettle();

    expect(find.text('Spesa'), findsOneWidget);
  });

  testWidgets('scorrere a destra spunta senza togliere la riga',
      (tester) async {
    await provider.addTodo(title: 'Spesa');
    await pumpPage(tester);

    await tester.drag(find.text('Spesa'), const Offset(400, 0));
    await tester.pumpAndSettle();

    // Spuntato davvero...
    expect(provider.todos.single.completed, isTrue);
    // ...e la riga non e' sparita dall'elenco con un'animazione: e' finita nella
    // fascia dei completati, che sta chiusa.
    expect(find.text('Completati (1)'), findsOneWidget);
    expect(find.text('Spesa'), findsNothing);
  });

  testWidgets('l\'intestazione dice dove sei, quanti, e i filtri — a scala 1,3',
      (tester) async {
    // La scala del telefono (1,3): e' li' che una riga di tre cose trabocca, e
    // un overflow fa fallire il test da solo.
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await provider.addTodo(title: 'Spesa');
    await provider.addTodo(title: 'Latte');
    await pumpPage(tester);

    // 1. **Dove sei**: il nome della vista, nel corpo grande (era titleMedium).
    final tema = Theme.of(tester.element(find.byType(TodoHeader)));
    final nome = tester.widget<Text>(find.text('Tutte'));
    expect(
      nome.style?.fontSize,
      tema.textTheme.titleLarge?.fontSize,
      reason:
          'il nome della vista e la cosa piu\' importante della riga: si vede',
    );

    // 2. **Quanti**: un numero, non una nota a pie' di riga.
    final conteggio = tester.widget<Text>(
      find.byKey(const ValueKey('conteggio-todo')),
    );
    expect(conteggio.data, '2 To do');
    expect(
      conteggio.style?.fontSize,
      tema.textTheme.titleMedium?.fontSize,
      reason:
          'il conteggio ha il corpo di un numero, non quello di una didascalia',
    );

    // 3. **I filtri**: una pastiglia (la stessa lingua dell'agenda), che dice
    // quanti sono attivi.
    expect(find.byType(FilterPill), findsOneWidget);
    expect(find.text('Filtri'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('apri-filtri')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filtro-priorita-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtri'));
    await tester.pumpAndSettle();

    // Chiuso il foglio, la pastiglia dice quanti filtri sono attivi.
    expect(find.text('Filtri · 1'), findsOneWidget);
  });
}
