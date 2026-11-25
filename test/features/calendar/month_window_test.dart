import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/calendar/month_window.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/filters/filtro_condiviso.dart';
import 'package:planner/features/todos/todo_hidden.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_recurrence.dart';

/// La finestra della griglia del mese: era il pezzo che stava dentro il `build`
/// della vista (e che chiedeva i todo un giorno per volta). Qui si prova senza
/// disegnare niente.
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

  MonthWindow finestra(DateTime focused, [DateTime? selected]) =>
      MonthWindow.of(
        events: events,
        todos: todos,
        focusedDay: focused,
        selectedDay: selected ?? focused,
        // Il filtro di partenza: non vincola niente (le regole del filtro hanno
        // il loro test, in `test/features/filters/`).
        filtro: const FiltroCondiviso(),
      );

  test('la finestra è il mese più una settimana per parte', () {
    final (from, to) = MonthWindow.windowOf(DateTime(2026, 9, 14));
    // 1 settembre meno 7 giorni, 30 settembre più 7.
    expect(from, DateTime(2026, 8, 25));
    expect(to, DateTime(2026, 10, 7));
  });

  test('un mese vuoto non inventa niente', () {
    final vuota = finestra(DateTime(2026, 9, 14));
    expect(vuota.eventsByDay, isEmpty);
    expect(vuota.todoCounts, isEmpty);
    expect(vuota.todosOfSelectedDay, isEmpty);
    expect(vuota.occurrencesOfSelectedDay, isEmpty);
    expect(vuota.needsMoreLine, isFalse);
  });

  test('un ricorrente compare in ogni giorno che gli tocca, non una volta sola',
      () async {
    await events.addEvent(
      title: 'Palestra',
      start: DateTime(2026, 9, 1, 18),
      end: DateTime(2026, 9, 1, 19),
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO',
    );

    final m = finestra(DateTime(2026, 9, 14));
    // I lunedì della finestra: 14, 21, 28 settembre e 5 ottobre.
    expect(m.eventsByDay[DateTime(2026, 9, 14)]!.single.title, 'Palestra');
    expect(m.eventsByDay[DateTime(2026, 9, 21)], hasLength(1));
    expect(m.eventsByDay[DateTime(2026, 9, 22)], isNull);
    expect(m.eventsByDay[DateTime(2026, 10, 5)], hasLength(1));
    // Il giorno scelto porta solo le sue occorrenze.
    expect(m.occurrencesOfSelectedDay, hasLength(1));
  });

  test('i conteggi dei todo: i fatti restano, il segno li toglie', () async {
    await todos.addTodo(title: 'Spesa', dueDate: DateTime(2026, 9, 14));
    await todos.addTodo(title: 'Farmacia', dueDate: DateTime(2026, 9, 14));
    await todos.addTodo(title: 'Bollo', dueDate: DateTime(2026, 9, 20));
    await todos.addTodo(
      title: 'Ogni giorno',
      dueDate: DateTime(2026, 9, 1),
      recurrenceRule: 'FREQ=DAILY',
    );

    var m = finestra(DateTime(2026, 9, 14));
    // Il 14: due todo singoli + l'occorrenza del ricorrente.
    expect(m.todoCounts[DateTime(2026, 9, 14)], 3);
    expect(m.todoCounts[DateTime(2026, 9, 20)], 2); // bollo + ricorrente

    // Confermata l'occorrenza del 14 per il ricorrente: **resta nel conteggio**,
    // perche' resta nella striscia (si vede che e' fatta: barrata).
    final ricorrente = todos.todos.firstWhere(
      (todo) => todo.recurrenceRule.isNotEmpty,
    );
    // `toggleForDay` scrive e aggiorna la cache in modo sincrono (la scrittura
    // su SQLite lo è): non c'è niente da aspettare.
    todos.toggleForDay(ricorrente, DateTime(2026, 9, 14));
    m = finestra(DateTime(2026, 9, 14));
    expect(
      m.todoCounts[DateTime(2026, 9, 14)],
      3,
      reason: 'una occorrenza fatta si vede (barrata) e si conta',
    );

    // A togliere un todo dal calendario e' **il segno**, non la spunta.
    final spesa = todos.todos.firstWhere((todo) => todo.title == 'Spesa');
    await todos.hideFromCalendar(spesa);
    m = finestra(DateTime(2026, 9, 14));
    expect(m.todoCounts[DateTime(2026, 9, 14)], 2);
    expect(
      [for (final todo in m.todosOfSelectedDay) todo.title],
      isNot(contains('Spesa')),
      reason: 'il segno vale anche per la lista del giorno scelto',
    );
  });

  test('la riga cresce solo quando un giorno ha più di tre eventi', () async {
    for (var i = 0; i < 3; i++) {
      await events.addEvent(
        title: 'Evento $i',
        start: DateTime(2026, 9, 14, 9 + i),
        end: DateTime(2026, 9, 14, 10 + i),
      );
    }
    expect(finestra(DateTime(2026, 9, 14)).needsMoreLine, isFalse);

    await events.addEvent(
      title: 'Quarto',
      start: DateTime(2026, 9, 14, 16),
      end: DateTime(2026, 9, 14, 17),
    );
    expect(finestra(DateTime(2026, 9, 14)).needsMoreLine, isTrue);
  });
}
