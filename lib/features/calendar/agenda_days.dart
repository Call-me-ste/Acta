import '../events/domain/event_occurrence.dart';
import '../events/event_provider.dart';
import '../filters/filtro_condiviso.dart';
import '../todos/domain/todo.dart';
import '../todos/domain/todo_dates.dart';
import '../todos/todo_provider.dart';
import '../todos/todo_windows.dart';
import 'day_axis.dart';

/// Un giorno dell'agenda, con dentro quello che succede quel giorno.
///
/// Esiste solo per i giorni che hanno **qualcosa**: un giorno vuoto non è
/// un'intestazione da mostrare, è spazio bianco.
class GiornoDellAgenda {
  const GiornoDellAgenda({
    required this.day,
    required this.allDay,
    required this.timed,
    required this.todos,
  });

  final DateTime day;

  /// Gli eventi di giornata intera: la pagina li mette in cima al gruppo.
  final List<EventOccurrence> allDay;

  /// Gli eventi con un orario, in ordine di inizio.
  final List<EventOccurrence> timed;

  /// I todo del giorno, nell'ordine del provider (prima chi ha un orario).
  final List<Todo> todos;

  int get eventi => allDay.length + timed.length;
}

/// I giorni dell'agenda: da [from] in avanti per [giorni] giorni, **solo quelli
/// che hanno qualcosa**.
///
/// Sta fuori dal widget perché è logica dei dati (qui non entra Material, e il
/// file della pagina ha un tetto di righe): così il raggruppamento, l'ordine
/// dentro il giorno e i giorni vuoti si provano senza disegnare.
///
/// L'orizzonte arriva dal filtro: prima erano trenta giorni fissi, adesso sono
/// quelli che l'utente ha scelto di guardare.
List<GiornoDellAgenda> giorniDellAgenda({
  required DateTime from,
  required int giorni,
  required EventProvider events,
  required TodoProvider todos,
  required FiltroCondiviso filtro,
}) {
  final inizio = dayOnly(from);
  final primo = DayAxis.indexOf(inizio);
  // La finestra degli eventi è `[da, a)`: l'ultimo giorno che si guarda è
  // `giorni - 1`; i todo si chiedono **inclusivi**, come li chiede il resto
  // dell'app.
  final fine = DayAxis.dayAt(primo + giorni - 1);

  final eventi = filtro.mostraEventi
      ? filtro.filtraEventi(
          events.occurrencesBetween(inizio, DayAxis.dayAt(primo + giorni)),
        )
      : const <EventOccurrence>[];
  final todoPerGiorno =
      filtro.mostraTodo ? todos.todosByDay(inizio, fine) : const {};

  final eventiPerGiorno = <DateTime, List<EventOccurrence>>{};
  for (final occurrence in eventi) {
    (eventiPerGiorno[occurrence.date] ??= []).add(occurrence);
  }

  final risultato = <GiornoDellAgenda>[];
  for (var scarto = 0; scarto < giorni; scarto++) {
    final giorno = DayAxis.dayAt(primo + scarto);
    final delGiorno = eventiPerGiorno[giorno] ?? const <EventOccurrence>[];
    final todo = filtro.filtraTodo(todoPerGiorno[giorno] ?? const <Todo>[]);
    if (delGiorno.isEmpty && todo.isEmpty) continue;

    risultato.add(
      GiornoDellAgenda(
        day: giorno,
        allDay: [
          for (final occurrence in delGiorno)
            if (occurrence.event.allDay) occurrence,
        ],
        timed: [
          for (final occurrence in delGiorno)
            if (!occurrence.event.allDay) occurrence,
        ]..sort((a, b) => a.start.compareTo(b.start)),
        todos: todo,
      ),
    );
  }
  return risultato;
}
