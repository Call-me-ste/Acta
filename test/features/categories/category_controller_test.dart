import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/categories/category_ids.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/categories/category_repair.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/todos/domain/todo.dart';

/// Le categorie: gli id sulle righe, la conversione della vecchia colonna di
/// testo libero, e cosa succede agli elementi quando una categoria sparisce.
///
/// Girano su un database vero in memoria perche' quello che si vuole provare e'
/// proprio **cosa resta scritto** — sulle righe e in outbox — dopo ogni
/// operazione.
void main() {
  late DatabaseService db;
  late CategoryController controller;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    controller = CategoryController(db);
  });

  tearDown(() => db.close());

  test('gli id: ordine scelto, niente doppioni, tetto di tre', () {
    expect(encodeCategoryIds(['b', 'a', 'b', 'c', 'd']), 'b,a,c');
    expect(encodeCategoryIds(const []), '');
    expect(decodeCategoryIds(' b , , a '), ['b', 'a']);
    expect(decodeCategoryIds(null), isEmpty);
    expect(decodeCategoryIds('a,b,c,d'), hasLength(maxCategoriesPerItem));
  });

  test('creare, rinominare, ritrovare per nome', () async {
    final casa = await controller.create(
      name: 'Casa',
      emoji: '🏠',
      colorHex: '#ff8800',
    );

    expect(controller.all, hasLength(1));
    expect(controller.byName('  casa '), isNotNull);
    expect(controller.byId(casa.id)!.emoji, '🏠');
    expect(db.outbox.pending(), hasLength(1));

    await controller.save(casa.copyWith(name: 'Casa e giardino'));

    expect(controller.byId(casa.id)!.name, 'Casa e giardino');
    // Il clock avanza a ogni scrittura: e' quello che il sync confronta.
    expect(controller.byId(casa.id)!.version, 2);
  });

  test('evento e todo tengono le loro categorie e si rileggono dal database',
      () async {
    final lavoro = await controller.create(name: 'Lavoro');
    final casa = await controller.create(name: 'Casa');

    db.insertTodo({
      'id': 't1',
      'title': 'Spesa',
      'category_ids': encodeCategoryIds([lavoro.id, casa.id]),
    });
    db.insertEvent({
      'id': 'e1',
      'title': 'Riunione',
      'start_time': 1000,
      'end_time': 2000,
      'category_ids': encodeCategoryIds([lavoro.id]),
    });

    final todo = Todo.fromRow(db.getTodos().single);
    final event = Event.fromRow(db.getEvents().single);
    expect(todo.categoryIds, [lavoro.id, casa.id]);
    expect(event.categoryIds, [lavoro.id]);
    // E l'ordine scelto si ritrova nei nomi, non solo negli id.
    expect(
      controller.byIds(todo.categoryIds).map((categoria) => categoria.name),
      ['Lavoro', 'Casa'],
    );
  });

  test('eliminare una categoria stacca solo lei, non cancella gli elementi',
      () async {
    final lavoro = await controller.create(name: 'Lavoro');
    final casa = await controller.create(name: 'Casa');
    db.insertTodo({
      'id': 't1',
      'title': 'Spesa',
      'category_ids': encodeCategoryIds([lavoro.id, casa.id]),
    });
    db.insertEvent({
      'id': 'e1',
      'title': 'Riunione',
      'start_time': 1000,
      'end_time': 2000,
      'category_ids': encodeCategoryIds([lavoro.id]),
    });

    // La conferma di eliminazione lo dice all'utente: la usano due elementi.
    expect(controller.usageCount(lavoro.id), 2);

    await controller.remove(lavoro.id);

    expect(controller.byId(lavoro.id), isNull);
    expect(Todo.fromRow(db.getTodos().single).categoryIds, [casa.id]);
    expect(Event.fromRow(db.getEvents().single).categoryIds, isEmpty);
    // Le due righe toccate viaggiano, altrimenti l'altro dispositivo le
    // terrebbe ancora con la categoria che qui non esiste piu'.
    final pending = db.outbox.pending();
    expect(
      pending.where((row) => row['entity_type'] == 'todo'),
      hasLength(1),
    );
    expect(
      pending.where((row) => row['entity_type'] == 'event'),
      hasLength(1),
    );
  });

  test('la vecchia colonna category diventa una categoria vera, una volta sola',
      () async {
    db.insertTodo({'id': 't1', 'title': 'Spesa'});
    db.insertTodo({'id': 't2', 'title': 'Buste'});
    // Un database di prima: la colonna di testo libero, riempita a mano.
    db.instance
        .execute("UPDATE todos SET category = '  Lavoro  ' WHERE id = 't1'");
    db.instance.execute("UPDATE todos SET category = 'lavoro' WHERE id = 't2'");

    // Un controller nuovo: la conversione la fa il costruttore, come all'avvio.
    final secondo = CategoryController(db);

    // Un nome solo, non due: la conversione non guarda le maiuscole.
    expect(secondo.all, hasLength(1));
    final categoria = secondo.all.single;
    expect(categoria.name, 'Lavoro');
    for (final todo in db.getTodos().map(Todo.fromRow)) {
      expect(todo.categoryIds, [categoria.id]);
    }
    // La colonna vecchia si svuota: al secondo avvio non c'e' piu' niente.
    expect(db.categories.legacyTodoRows(), isEmpty);
    expect(CategoryController(db).all, hasLength(1));
  });

  test('stesso nome e stessa emoji: e\' una categoria sola', () async {
    final prima = await controller.create(name: 'Lavoro', emoji: '💼');
    final seconda = await controller.create(name: 'LAVORO', emoji: '💼');
    final terza = await controller.create(name: '  LaVoRO  ', emoji: '💼');
    final quarta = await controller.create(name: 'Lavoro', emoji: '💼');

    expect(controller.all, hasLength(1));
    expect(seconda.id, prima.id);
    expect(terza.id, prima.id);
    expect(quarta.id, prima.id);
    // E non si accoda un'operazione in piu' per un doppione che non esiste.
    expect(db.outbox.pending(), hasLength(1));
  });

  test('gli spazi non fanno una categoria nuova', () async {
    final senza = await controller.create(name: 'Casa');
    final spazioInTesta = await controller.create(name: '  casa  ');
    final emojiVuota = await controller.create(name: 'CASA', emoji: ' ');

    expect(controller.all, hasLength(1));
    expect(spazioInTesta.id, senza.id);
    expect(emojiVuota.id, senza.id);
  });

  test('emoji diversa = categoria diversa, anche con lo stesso nome', () async {
    final valigetta = await controller.create(name: 'Lavoro', emoji: '💼');
    final casa = await controller.create(name: 'lavoro', emoji: '🏠');

    expect(controller.all, hasLength(2));
    expect(valigetta.id, isNot(casa.id));
  });

  test('rinominare su un nome che esiste non fonde di nascosto', () async {
    await controller.create(name: 'Lavoro', emoji: '💼');
    final casa = await controller.create(name: 'Casa', emoji: '💼');

    // Lo stesso nome e la stessa emoji di un'altra: si rifiuta e lo si dice.
    expect(await controller.save(casa.copyWith(name: 'LAVORO')), isFalse);
    expect(controller.byId(casa.id)!.name, 'Casa');
    expect(controller.all, hasLength(2));

    // Un nome libero invece si salva.
    expect(await controller.save(casa.copyWith(name: 'Ufficio')), isTrue);
    expect(controller.byId(casa.id)!.name, 'Ufficio');
  });

  test('i doppioni gia\' creati si uniscono, e gli elementi li seguono',
      () async {
    // Due righe scritte direttamente, come le avrebbe lasciate la versione
    // senza la regola.
    db.categories.upsert({'id': 'a', 'name': 'Lavoro', 'emoji': '💼'});
    db.categories.upsert({'id': 'b', 'name': 'LAVORO', 'emoji': '💼'});
    db.insertTodo({
      'id': 't1',
      'title': 'Spesa',
      'category_ids': encodeCategoryIds(['b', 'x']),
    });
    db.insertTodo({
      'id': 't2',
      'title': 'Buste',
      'category_ids': encodeCategoryIds(['a']),
    });

    // Il controller nuovo fa la fusione all'avvio, come nell'app.
    final secondo = CategoryController(db);

    expect(secondo.all, hasLength(1));
    expect(secondo.all.single.id, 'a');
    // t1 puntava alla vittima: adesso punta a quella tenuta, e l'altra
    // categoria che aveva resta dove stava.
    expect(
      Todo.fromRow(db.getTodos().firstWhere((row) => row['id'] == 't1'))
          .categoryIds,
      ['a', 'x'],
    );
    expect(
      Todo.fromRow(db.getTodos().firstWhere((row) => row['id'] == 't2'))
          .categoryIds,
      ['a'],
    );
    // Idempotente: al secondo avvio non c'e' piu' niente da unire.
    final riparazione = CategoryRepair(db);
    expect(
      riparazione.mergeDuplicates([
        for (final categoria in secondo.all)
          ItemCategoryLike(
            id: categoria.id,
            key: CategoryController.keyOf(categoria.name, categoria.emoji),
            version: categoria.version,
          ),
      ]),
      0,
    );
  });
}
