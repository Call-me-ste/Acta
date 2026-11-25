import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/features/todos/todo_filter.dart';

/// Il filtro della scheda Todo: la regola pura, provata senza disegnare niente
/// e senza aspettare mezzanotte (il giorno si passa da fuori).
///
/// Gli **scaduti** e i **completati** non sono viste: stanno nelle due fasce
/// (sopra e sotto), quindi qui non c'e' niente da provare per loro — solo che
/// l'elenco non li mostri.
void main() {
  final oggi = DateTime(2026, 9, 17);

  Todo todo({
    DateTime? due,
    int priority = 0,
    List<String> categoryIds = const [],
  }) {
    return Todo(
      id: 't',
      title: 'x',
      dueDate: due,
      priority: priority,
      categoryIds: categoryIds,
    );
  }

  bool passa(Todo t, TodoFilter filtro, {bool done = false}) =>
      filtro.matches(t, done: done, today: oggi);

  test('«Tutte» non vincola niente fra quelli da fare', () {
    expect(passa(todo(), const TodoFilter()), isTrue);
    expect(passa(todo(due: oggi), const TodoFilter()), isTrue);
    expect(
      passa(todo(due: oggi.subtract(const Duration(days: 9))),
          const TodoFilter()),
      isTrue,
    );
  });

  test('quello che si e\' spuntato non compare in nessuna vista', () {
    for (final range in TodoRange.values) {
      expect(
        passa(todo(due: oggi), TodoFilter(range: range), done: true),
        isFalse,
        reason: 'vista ${range.name}',
      );
    }
  });

  test('gli intervalli contano i giorni di calendario', () {
    const oggiSolo = TodoFilter(range: TodoRange.oggi);
    const oggiEDomani = TodoFilter(range: TodoRange.oggiEDomani);
    const prossimi7 = TodoFilter(range: TodoRange.prossimi7);
    const senzaData = TodoFilter(range: TodoRange.senzaData);

    expect(passa(todo(due: oggi), oggiSolo), isTrue);
    expect(
      passa(todo(due: oggi.add(const Duration(days: 1))), oggiSolo),
      isFalse,
    );

    // «Oggi e domani» prende **entrambi** (era «Domani», che prendeva solo il
    // giorno dopo).
    expect(
      passa(todo(due: oggi.add(const Duration(days: 1))), oggiEDomani),
      isTrue,
    );
    expect(passa(todo(due: oggi), oggiEDomani), isTrue);
    expect(
      passa(todo(due: oggi.add(const Duration(days: 2))), oggiEDomani),
      isFalse,
      reason: 'dopodomani non e\' ne\' oggi ne\' domani',
    );

    expect(
      passa(todo(due: oggi.add(const Duration(days: 7))), prossimi7),
      isTrue,
    );
    expect(
      passa(todo(due: oggi.add(const Duration(days: 8))), prossimi7),
      isFalse,
    );
    // Una scaduta non e' "nei prossimi 7 giorni": ha la sua fascia in cima.
    expect(
      passa(todo(due: oggi.subtract(const Duration(days: 1))), prossimi7),
      isFalse,
    );

    expect(passa(todo(), senzaData), isTrue);
    expect(passa(todo(due: oggi), senzaData), isFalse);
  });

  test('priorita\' e categorie si sommano alla vista', () {
    const filtro = TodoFilter(priorities: {3}, categoryIds: {'lavoro'});

    expect(passa(todo(priority: 3, categoryIds: ['lavoro']), filtro), isTrue);
    // Basta una delle categorie scelte, non tutte.
    expect(
      passa(todo(priority: 3, categoryIds: ['casa', 'lavoro']), filtro),
      isTrue,
    );
    expect(passa(todo(priority: 3, categoryIds: ['casa']), filtro), isFalse);
    expect(passa(todo(priority: 1, categoryIds: ['lavoro']), filtro), isFalse);
  });

  test('i filtri fini valgono anche per i completati', () {
    const filtro = TodoFilter(priorities: {2});

    // E' la regola che usa la fascia "Completati": la vista non la riguarda,
    // le categorie e le priorita' si'.
    expect(filtro.passesCategoriesAndPriorities(todo(priority: 2)), isTrue);
    expect(filtro.passesCategoriesAndPriorities(todo(priority: 0)), isFalse);
  });

  test('il filtro vuoto si riconosce da solo', () {
    expect(const TodoFilter().isEmpty, isTrue);
    expect(const TodoFilter(range: TodoRange.oggi).isEmpty, isFalse);
    expect(const TodoFilter(priorities: {0}).isEmpty, isFalse);
    expect(const TodoFilter(categoryIds: {'x'}).isEmpty, isFalse);
  });
}
