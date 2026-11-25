import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/dev/demo_data.dart';
import 'package:planner/dev/prova_notifiche.dart';

/// I dati di prova: si caricano, si tolgono, e non toccano **niente** di quello
/// che c'era prima. La rimozione esatta e' l'unica cosa che rende utilizzabile
/// un comando che scrive nel database dell'utente.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  int conPrefisso(Iterable<String> ids) =>
      ids.where((id) => id.startsWith(DemoData.idPrefix)).length;

  test('carica un\'agenda piena', () async {
    final quanti = await DemoData.load(db);

    expect(quanti, greaterThan(200));
    expect(
      conPrefisso(db.getTodos().map((row) => row['id'] as String)),
      DemoData.todos + DemoData.recurringTodos,
    );
    expect(
      conPrefisso(db.getEvents().map((row) => row['id'] as String)),
      DemoData.events + DemoData.series + ProvaNotifiche.quanti,
    );
    expect(db.categories.all(), hasLength(5));

    // Roba vera, non righe vuote: lezioni che ricorrono, todo con scadenza,
    // priorita' e categorie diverse, alcuni fatti.
    final eventi = db.getEvents();
    expect(
      eventi.where((row) => (row['recurrence_rule'] as String).isNotEmpty),
      hasLength(DemoData.series),
    );
    final todos = db.getTodos();
    expect(todos.where((row) => (row['due_date'] as int?) != null).length,
        greaterThan(100));
    expect(todos.map((row) => row['priority']).toSet(), {0, 1, 2, 3});
    expect(todos.where((row) => (row['completed'] as int) == 1), isNotEmpty);
  });

  test('caricare due volte non raddoppia', () async {
    await DemoData.load(db);
    await DemoData.load(db);

    expect(
      conPrefisso(db.getTodos().map((row) => row['id'] as String)),
      DemoData.todos + DemoData.recurringTodos,
    );
  });

  test('rimuove solo i dati di prova', () async {
    // Quello che l'utente ha di suo: non deve sparire.
    db.insertTodo({'id': 'mio-1', 'title': 'Compito vero'});
    db.insertEvent({
      'id': 'mio-e',
      'title': 'Evento vero',
      'start_time': 1,
      'end_time': 2,
    });
    db.categories.upsert({'id': 'mia-cat', 'name': 'Mia'});

    await DemoData.load(db);
    final tolti = DemoData.remove(db);

    expect(tolti, greaterThan(200));
    expect(db.getTodos().single['id'], 'mio-1');
    expect(db.getEvents().single['id'], 'mio-e');
    expect(db.categories.all().single['id'], 'mia-cat');
  });

  test('su un database vuoto la rimozione non fa rumore', () async {
    expect(DemoData.remove(db), 0);
  });
}
