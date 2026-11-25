import '../events/domain/event_occurrence.dart';
import '../events/event_provider.dart';
import '../filters/filtro_condiviso.dart';
import '../todos/domain/todo.dart';
import '../todos/todo_provider.dart';
import '../todos/todo_windows.dart';

/// Quello che la griglia del mese deve sapere, calcolato **una volta sola**.
///
/// Sta fuori dal widget perché è logica dei dati, non disegno: qui non entra
/// Material, e si può provare senza terminale. La vista dello mese chiedeva
/// queste quattro cose in mezzo al `build` (eventi per giorno, todo per giorno,
/// todo del giorno scelto, occorrenze del giorno scelto) e ogni ricostruzione le
/// rifaceva tutte — con la differenza che i todo li chiedeva **un giorno per
/// volta**, cioè ~45 giri su tutti i todo.
class MonthWindow {
  const MonthWindow({
    required this.eventsByDay,
    required this.todoCounts,
    required this.todosOfSelectedDay,
    required this.occurrencesOfSelectedDay,
    required this.needsMoreLine,
  });

  /// Gli eventi della griglia, per giorno (compresi i giorni di prima e dopo il
  /// mese che le righe mostrano).
  final Map<DateTime, List<EventOccurrence>> eventsByDay;

  /// Quanti todo **non fatti** cadono in ogni giorno della griglia, solo per i
  /// giorni che ne hanno almeno uno.
  final Map<DateTime, int> todoCounts;

  /// I todo del giorno scelto: la sezione sotto la griglia.
  final List<Todo> todosOfSelectedDay;

  /// Le occorrenze del giorno scelto: la lista sotto la griglia.
  final List<EventOccurrence> occurrencesOfSelectedDay;

  /// Vero se un giorno della griglia ha più di tre eventi: la riga deve crescere
  /// per far stare il «+N».
  final bool needsMoreLine;

  /// La finestra della griglia: il mese più una settimana per parte.
  static (DateTime, DateTime) windowOf(DateTime focusedDay) {
    final first = DateTime(focusedDay.year, focusedDay.month, 1);
    final last = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    return (
      DateTime(first.year, first.month, first.day - 7),
      DateTime(last.year, last.month, last.day + 7),
    );
  }

  /// Le **due finestre** della griglia: gli eventi per la griglia del mese e i
  /// todo giorno per giorno. Sono le stesse che chiede `of`, e stanno qui perche'
  /// anche il **precarico** deve chiedere quelle: scaldare una cache che nessuno
  /// legge non servirebbe a niente.
  ///
  /// Il filtro si applica **qui**, dove i dati si leggono: cosi' la finestra che
  /// finisce in memoria contiene gia' quello che la griglia disegna, e non c'e'
  /// un secondo posto in cui ricordarsi di filtrarla.
  static ({List<EventOccurrence> eventi, Map<DateTime, List<Todo>> todo})
      finestre({
    required EventProvider events,
    required TodoProvider todos,
    required DateTime focusedDay,
    required FiltroCondiviso filtro,
  }) {
    final (windowStart, windowEnd) = windowOf(focusedDay);
    return (
      eventi: [
        for (final occurrence in events.occurrencesBetween(
          windowStart,
          DateTime(windowEnd.year, windowEnd.month, windowEnd.day + 1),
        ))
          if (filtro.passaEvento(occurrence)) occurrence,
      ],
      todo: {
        for (final entry in todos.todosByDay(windowStart, windowEnd).entries)
          entry.key: [
            for (final todo in entry.value)
              if (filtro.passaTodo(todo)) todo,
          ],
      },
    );
  }

  /// Costruisce tutto quello che serve alla griglia, con **una** query per gli
  /// eventi e **una passata** sui todo.
  factory MonthWindow.of({
    required EventProvider events,
    required TodoProvider todos,
    required DateTime focusedDay,
    required DateTime selectedDay,
    required FiltroCondiviso filtro,
  }) {
    final calcolate = finestre(
      events: events,
      todos: todos,
      focusedDay: focusedDay,
      filtro: filtro,
    );

    final byDay = <DateTime, List<EventOccurrence>>{};
    for (final occurrence in calcolate.eventi) {
      byDay.putIfAbsent(occurrence.date, () => []).add(occurrence);
    }

    final counts = <DateTime, int>{};
    for (final entry in calcolate.todo.entries) {
      if (entry.value.isNotEmpty) counts[entry.key] = entry.value.length;
    }

    return MonthWindow(
      eventsByDay: byDay,
      todoCounts: counts,
      // Le due liste del giorno scelto si chiedono al provider e si filtrano
      // qui: senza, la fascia in fondo e l'elenco sotto la griglia mostrerebbero
      // quello che il filtro ha appena nascosto.
      todosOfSelectedDay: [
        for (final todo in todos.todosForDate(selectedDay))
          if (filtro.passaTodo(todo)) todo,
      ],
      occurrencesOfSelectedDay: [
        for (final occurrence in events.occurrencesForDate(selectedDay))
          if (filtro.passaEvento(occurrence)) occurrence,
      ],
      needsMoreLine: byDay.values.any((dayEvents) => dayEvents.length > 3),
    );
  }
}
