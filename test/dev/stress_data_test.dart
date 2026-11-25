import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/dev/demo_data.dart';
import 'package:planner/dev/stress_data.dart';

/// I dati di **stress**: il carico cattivo che serve a misurare.
///
/// Due cose da provare, e non sono le misure (quelle si fanno sul telefono):
/// che il carico ci sia **tutto** (300 eventi nello stesso giorno, 2000 todo) e
/// che si tolga **esattamente** quello, senza portarsi via un dato vero.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  test('carica il carico promesso, e in un giorno solo', () async {
    final quanti = await StressData.load(db, from: DateTime(2026, 9, 23));

    expect(quanti,
        StressData.eventi + StressData.serieRicorrenti + StressData.todo);
    expect(db.getTodos(), hasLength(StressData.todo));

    // Gli eventi **di quel giorno**: 300, tutti insieme. E' il caso che mette
    // alla prova la griglia delle ore.
    final inizio = DateTime(2026, 9, 23);
    expect(
      db.getEventsBetween(inizio, inizio.add(const Duration(days: 1))),
      hasLength(StressData.eventi),
    );
    expect(db.getRecurringEvents(), hasLength(StressData.serieRicorrenti));
  });

  test('si toglie esattamente quello, e i dati veri restano', () async {
    // Un dato "vero" dell'utente, con i suoi id.
    db.insertTodo({'id': 'mio-todo', 'title': 'Comprare il latte'});
    db.insertEvent({
      'id': 'mio-evento',
      'title': 'Dentista',
      'start_time': 1000,
      'end_time': 2000,
    });
    await DemoData.load(db);

    await StressData.load(db);
    final tolti = StressData.remove(db);

    expect(tolti,
        StressData.eventi + StressData.serieRicorrenti + StressData.todo);
    expect(db.getTodos().map((riga) => riga['id']), contains('mio-todo'));
    expect(db.getEvents().map((riga) => riga['id']), contains('mio-evento'));
    // Nessun residuo di stress: ne' fra i todo ne' fra gli eventi (ricorrenti
    // compresi, che stanno in un'altra query).
    final residui = [
      ...db.getTodos(),
      ...db.getEvents(),
      ...db.getRecurringEvents(),
    ].where((riga) => (riga['id'] as String).startsWith(StressData.idPrefix));
    expect(residui, isEmpty);
    // I dati di prova sono un'altra cosa: restano anche loro.
    expect(db.getTodos().length, greaterThan(1));
  });

  test('caricarlo due volte non raddoppia niente', () async {
    await StressData.load(db);
    await StressData.load(db);

    expect(db.getTodos(), hasLength(StressData.todo));
    expect(db.getRecurringEvents(), hasLength(StressData.serieRicorrenti));
  });
}
