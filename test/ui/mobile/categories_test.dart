import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/categories_page.dart';
import 'package:planner/ui/mobile/item_form.dart';
import 'package:planner/ui/mobile/item_type.dart';

/// Le categorie dall'interfaccia: crearle, rinominarle, eliminarle (senza
/// portarsi via gli elementi) e sceglierle nel form, dove il tetto e' tre.
void main() {
  late DatabaseService db;
  late CategoryController categories;
  late TodoProvider todos;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    categories = CategoryController(db);
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  Widget harness(Widget child) => MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: db),
          ChangeNotifierProvider<CategoryController>.value(value: categories),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ChangeNotifierProvider<EventProvider>.value(
            value: EventProvider(db),
          ),
          ChangeNotifierProvider<AppSettingsController>.value(
            value: AppSettingsController(db.settings)..load(),
          ),
          ChangeNotifierProvider<PaletteController>.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
        ],
        child: MaterialApp(home: child),
      );

  /// Il form e' lungo: serve una tela alta, altrimenti i pulsanti restano fuori.
  Future<void> apriForm(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      harness(
        Scaffold(
          body: ItemForm(type: ItemType.todo, day: DateTime(2026, 9, 14)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Sceglie una categoria dal foglio del form.
  Future<void> scegli(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(const ValueKey('aggiungi-categoria')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('scegli-$id')));
    await tester.pumpAndSettle();
  }

  testWidgets('dalla pagina: crea, rinomina ed elimina', (tester) async {
    await tester.pumpWidget(harness(const CategoriesPage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nessuna categoria'), findsOneWidget);

    await tester.tap(find.text('Categoria'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nome-categoria')),
      'Lavoro',
    );
    await tester.tap(find.text('💼'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('salva-categoria')));
    await tester.pumpAndSettle();

    expect(categories.all, hasLength(1));
    expect(categories.all.single.name, 'Lavoro');
    expect(categories.all.single.emoji, '💼');
    expect(find.text('Lavoro'), findsWidgets);

    // Rinomina dal menu della riga.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifica'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nome-categoria')),
      'Ufficio',
    );
    await tester.tap(find.byKey(const ValueKey('salva-categoria')));
    await tester.pumpAndSettle();

    expect(categories.all.single.name, 'Ufficio');

    // Elimina: prima la conferma, che dice quanti elementi la usano.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Non la usa'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await tester.pumpAndSettle();

    expect(categories.all, isEmpty);
  });

  testWidgets('dal form: si sceglie, si salva e resta scritta', (tester) async {
    final lavoro = await categories.create(name: 'Lavoro', emoji: '💼');
    await categories.create(name: 'Casa', emoji: '🏠');

    await apriForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Spesa');
    await scegli(tester, lavoro.id);

    // La pastiglia si vede nel form, con l'emoji.
    expect(find.byKey(ValueKey('categoria-${lavoro.id}')), findsOneWidget);
    expect(find.text('💼 Lavoro'), findsOneWidget);

    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    // E finisce davvero in database, non solo sullo schermo.
    final salvato = Todo.fromRow(db.getTodos().single);
    expect(salvato.title, 'Spesa');
    expect(salvato.categoryIds, [lavoro.id]);
  });

  testWidgets('la categoria dà il colore di default al todo', (tester) async {
    final lavoro = await categories.create(
      name: 'Lavoro',
      colorHex: '#1E88E5',
    );
    await apriForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Spesa');
    await scegli(tester, lavoro.id);
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    final salvato = Todo.fromRow(db.getTodos().single);
    expect(salvato.colorIndex, 6);
  });

  testWidgets('il tetto è tre: oltre, il tasto si spegne', (tester) async {
    final uno = await categories.create(name: 'Uno');
    final due = await categories.create(name: 'Due');
    final tre = await categories.create(name: 'Tre');
    await categories.create(name: 'Quattro');

    await apriForm(tester);
    for (final id in [uno.id, due.id, tre.id]) {
      await scegli(tester, id);
    }

    expect(find.text('Tre: il massimo'), findsOneWidget);
    final bottone = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Tre: il massimo'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(bottone.onPressed, isNull);

    // Il quarto non si puo' aggiungere: il foglio non si apre nemmeno.
    await tester.tap(find.text('Tre: il massimo'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Nuova categoria'), findsNothing);
  });

  testWidgets('un doppio tocco su Salva non crea due categorie',
      (tester) async {
    await tester.pumpWidget(harness(const CategoriesPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Categoria'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nome-categoria')),
      'Lavoro',
    );

    // Due tocchi ravvicinati, senza aspettare che il primo finisca: e' il gesto
    // che creava due righe identiche.
    final salva = find.byKey(const ValueKey('salva-categoria'));
    await tester.tap(salva);
    await tester.tap(salva, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(categories.all, hasLength(1));
    expect(db.outbox.pending(), hasLength(1));
  });

  testWidgets('stesso nome a meno di maiuscole: non si crea, e lo dice',
      (tester) async {
    await categories.create(name: 'Lavoro', emoji: '💼');

    await tester.pumpWidget(harness(const CategoriesPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categoria'));
    await tester.pumpAndSettle();

    // Nome uguale scritto in un altro modo, stessa emoji: e' la stessa cosa.
    await tester.enterText(
      find.byKey(const ValueKey('nome-categoria')),
      'LAVORO',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '💼'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('salva-categoria')));
    await tester.pumpAndSettle();

    expect(categories.all, hasLength(1));
    expect(find.textContaining('Esiste già'), findsOneWidget);

    // Con un'emoji diversa invece e' un'altra categoria, ed e' voluto.
    await tester.tap(find.widgetWithText(ChoiceChip, '🏠'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('salva-categoria')));
    await tester.pumpAndSettle();

    expect(categories.all, hasLength(2));
    expect(categories.all.map((categoria) => categoria.emoji), contains('🏠'));
  });
}
