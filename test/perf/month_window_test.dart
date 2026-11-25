import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_windows.dart';

/// Quanto costa **disegnare un mese**: la finestra della griglia (una settimana
/// per parte) chiede gli eventi una volta e i todo giorno per giorno.
///
/// La verifica è **relativa**, non assoluta: il costo non deve dipendere da
/// quanto è lunga la storia di una serie. Se dipende, l'espansione sta
/// camminando dalla prima occorrenza invece di saltare alla finestra — ed è il
/// difetto trovato qui: 337 ms per disegnare un mese con serie nate anni prima,
/// sceso a 149 ms dopo la correzione (numeri di `flutter test`, che gira in JIT:
/// in profile sull'emulatore lo stesso lavoro costa pochi millisecondi).
void main() {
  /// Un archivio "vivo": eventi e todo con ricorrenze in mezzo, con la serie
  /// che nasce a `seriesStart`.
  Future<DatabaseService> seed(DateTime seriesStart) async {
    final db = DatabaseService();
    await db.init(dbPath: ':memory:');
    final events = EventProvider(db);
    final todos = TodoProvider(db);

    for (var i = 0; i < 120; i++) {
      final start = seriesStart.add(Duration(days: i * 3));
      await events.addEvent(
        title: 'Evento $i',
        start: start,
        end: start.add(const Duration(hours: 1)),
        recurrenceRule: i % 8 == 0 ? 'FREQ=WEEKLY;BYDAY=MO,FR' : '',
      );
    }
    for (var i = 0; i < 40; i++) {
      await todos.addTodo(
        title: 'Todo $i',
        dueDate: seriesStart.add(Duration(days: i * 7)),
        recurrenceRule: i % 4 == 0 ? 'FREQ=DAILY' : '',
      );
    }
    return db;
  }

  /// Il costo della finestra del mese, come la calcola la vista mese.
  int costOf(DatabaseService db) {
    final events = EventProvider(db);
    final todos = TodoProvider(db);
    final windowStart = DateTime(2026, 8, 25);
    final windowEnd = DateTime(2026, 10, 8);

    final watch = Stopwatch()..start();
    events.occurrencesBetween(
      windowStart,
      DateTime(windowEnd.year, windowEnd.month, windowEnd.day + 1),
    );
    for (var day = windowStart;
        !day.isAfter(windowEnd);
        day = DateTime(day.year, day.month, day.day + 1)) {
      todos.todosForDate(day);
    }
    watch.stop();
    return watch.elapsedMilliseconds;
  }

  test('la finestra del mese non dipende dalla lunghezza della storia',
      () async {
    final giovane = await seed(DateTime(2026, 8, 1));
    final vecchio = await seed(DateTime(2023, 1, 1));

    // Un giro a vuoto per scaldare le cache del processo.
    costOf(giovane);
    costOf(vecchio);

    final costoGiovane = costOf(giovane);
    final costoVecchio = costOf(vecchio);

    giovane.close();
    vecchio.close();

    expect(
      costoVecchio,
      lessThan(costoGiovane * 3 + 25),
      reason: 'una serie nata nel 2023 costa $costoVecchio ms contro '
          '$costoGiovane ms di una nata nel 2026: la storia viene percorsa '
          'tutta (l\'espansione deve saltare alla finestra)',
    );
  });

  test('la finestra dei todo si calcola una volta, non una per giorno',
      () async {
    // 300 todo, metà ricorrenti: abbastanza per vedere la differenza senza
    // pagare 8 secondi di suite.
    final db = DatabaseService();
    await db.init(dbPath: ':memory:');
    final provider = TodoProvider(db);
    for (var i = 0; i < 300; i++) {
      await provider.addTodo(
        title: 'Todo $i',
        dueDate: DateTime(2026, 9, 1).add(Duration(days: i % 120)),
        recurrenceRule: i % 2 == 0 ? 'FREQ=DAILY' : '',
      );
    }

    final from = DateTime(2026, 8, 25);
    final to = DateTime(2026, 10, 8);

    /// La forma vecchia: un giro per ogni giorno della griglia (~45), ognuno
    /// dei quali ri-analizzava la regola di **ogni** todo.
    int vecchiaForma() {
      final watch = Stopwatch()..start();
      for (var day = from;
          !day.isAfter(to);
          day = DateTime(day.year, day.month, day.day + 1)) {
        provider.todosForDate(day);
      }
      watch.stop();
      return watch.elapsedMicroseconds;
    }

    /// La forma nuova: una passata sola per l'intera finestra.
    int nuovaForma() {
      final watch = Stopwatch()..start();
      provider.todosByDay(from, to);
      watch.stop();
      return watch.elapsedMicroseconds;
    }

    // Un giro a vuoto per scaldare il processo (le prove girano in JIT).
    vecchiaForma();
    nuovaForma();

    final vecchio = vecchiaForma();
    final nuovo = nuovaForma();

    db.close();

    expect(
      nuovo,
      lessThan(vecchio / 4),
      reason: 'la finestra battuta costa $nuovo µs contro $vecchio µs della '
          'forma giorno-per-giorno: se sono vicini, qualcuno ha rimesso il '
          'ciclo per giorno (una `tryParse` per todo per ogni giorno)',
    );
  });
}
