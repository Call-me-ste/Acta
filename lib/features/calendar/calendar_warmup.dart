import '../events/event_provider.dart';
import '../filters/filtro_condiviso.dart';
import '../todos/todo_provider.dart';
import '../todos/todo_windows.dart';
import 'day_axis.dart';
import 'month_window.dart';

/// Il lunedì della settimana di `day`, sommando ai campi del calendario.
///
/// Qui e non nel widget perché è aritmetica di date, e perché la usano sia la
/// vista settimana sia il precarico: una regola, un posto.
DateTime mondayOf(DateTime day) =>
    DateTime(day.year, day.month, day.day + 1 - day.weekday);

/// Chiede ai provider, **una volta**, tutto quello che le tre viste del
/// calendario chiedono al loro primo disegno.
///
/// Perché esiste: ogni vista legge al primo disegno (`EventProvider` legge la
/// tabella alla prima richiesta, `TodoProvider` calcola la sua finestra alla
/// prima richiesta). Lasciandole fare, la lettura del database, il parsing e il
/// calcolo della finestra capitavano **dentro** il primo cambio vista, cioè nel
/// fotogramma in cui le viste si muovono. Il costo non sparisce: si sposta
/// all'apertura, dove non dà fastidio.
///
/// Le chiamate sono **le stesse** che fanno le viste: nessuna strada parallela
/// per gli stessi numeri, altrimenti il precarico scalderebbe una cache che
/// nessuno legge.
void warmUpCalendar({
  required EventProvider events,
  required TodoProvider todos,
  required DateTime focusedDay,
  required DateTime selectedDay,
  required FiltroCondiviso filtro,
}) {
  // Mese: la finestra della griglia (il mese più una settimana per parte) e i
  // conteggi dei todo per giorno. Col filtro, perche' la finestra che si scalda
  // deve essere **quella** che la griglia legge: una finestra senza filtro non la
  // legge nessuno.
  MonthWindow.of(
    events: events,
    todos: todos,
    focusedDay: focusedDay,
    selectedDay: selectedDay,
    filtro: filtro,
  );

  // Settimana: **la stessa** finestra che chiede la vista (`DayAxis.giorniAsseSettimana`,
  // cioè la settimana mostrata più la successiva). Chiedendone sette, il primo
  // cambio vista rileggeva il database per le colonne in più — e c'era un test
  // che se ne accorgeva.
  //
  // Poi i tre giorni che la `PageView` della vista giorno tiene vivi (il giorno
  // scelto e i due vicini). I todo li chiede solo la vista giorno, quindi la
  // settimana non si scalda: sarebbe lavoro che nessuno legge.
  final monday = mondayOf(selectedDay);
  events.occurrencesBetween(
    monday,
    DateTime(
      monday.year,
      monday.month,
      monday.day + DayAxis.giorniAsseSettimana,
    ),
  );
  for (final offset in [-1, 0, 1]) {
    final day = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day + offset,
    );
    events.occurrencesForDate(day);
    todos.todosForDate(day);
  }
}
