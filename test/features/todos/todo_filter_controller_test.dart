import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/todos/todo_filter.dart';
import 'package:planner/features/todos/todo_filter_controller.dart';

/// Il filtro ricordato fra un avvio e l'altro: e' una preferenza del device, e
/// deve reggere anche un valore scritto da una versione piu' recente.
void main() {
  late DatabaseService db;
  late TodoFilterController controller;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    controller = TodoFilterController(db.settings)..load();
  });

  tearDown(() => db.close());

  test('di partenza non vincola niente', () {
    expect(controller.isDefault, isTrue);
    expect(controller.filter.range, TodoRange.tutte);
    expect(controller.filter.categoryIds, isEmpty);
    expect(controller.filter.priorities, isEmpty);
  });

  test('le scelte sopravvivono a un nuovo avvio', () {
    controller.setRange(TodoRange.oggiEDomani);
    controller.toggleCategory('lavoro');
    controller.toggleCategory('casa');
    controller.toggleCategory('casa');
    controller.togglePriority(3);

    final riletto = TodoFilterController(db.settings)..load();

    expect(riletto.filter.range, TodoRange.oggiEDomani);
    expect(riletto.filter.categoryIds, {'lavoro'});
    expect(riletto.filter.priorities, {3});
    expect(riletto.isDefault, isFalse);
  });

  test('azzera riporta al filtro di partenza e toglie le chiavi', () {
    controller.setRange(TodoRange.oggiEDomani);
    controller.togglePriority(1);
    controller.reset();

    expect(controller.isDefault, isTrue);
    // Le chiavi spariscono: il default e' "non impostato", non una copia.
    expect(db.settings.get('todoFilterRange'), isNull);
    expect(db.settings.get('todoFilterCategories'), isNull);
    expect(db.settings.get('todoFilterPriorities'), isNull);
  });

  test('un valore rotto non lascia la scheda vuota', () {
    db.settings.set('todoFilterRange', 'dopodomani');
    db.settings.set('todoFilterPriorities', 'x,2,,');
    db.settings.set('todoFilterCategories', ' lavoro ,, casa ');

    final riletto = TodoFilterController(db.settings)..load();

    // L'intervallo sconosciuto ricade su "Tutte"; quel che si legge si tiene.
    expect(riletto.filter.range, TodoRange.tutte);
    expect(riletto.filter.priorities, {2});
    expect(riletto.filter.categoryIds, {'lavoro', 'casa'});
  });
}
