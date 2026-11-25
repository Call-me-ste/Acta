import 'package:flutter/material.dart';

import '../../features/events/domain/event_occurrence.dart';
import '../../features/todos/domain/todo.dart';
// La colonna di un giorno (eventi, todo e il bollino del cluster) sta in un
// file suo per il tetto delle 300 righe di questo.
import 'day_timeline.dart';
import 'week_day_column.dart';

/// Le colonne dell'asse dei giorni: griglia e blocchi evento con **titolo sempre
/// dentro** (9,5 sp, ellissi) e orario nei blocchi abbastanza alti.
///
/// Ogni giorno è una `WeekDayColumn`: il cap a 2 caselle per cluster e il
/// bollino «+N» vivono là dentro; qui la larghezza arriva da fuori, perché le
/// colonne sono più larghe dello schermo e si pannano in orizzontale.
///
/// La **tinta del giorno scelto non sta qui**: è salita in `week_view.dart`.
/// Sembra un dettaglio di disegno e non lo è — era la ragione per cui cambiando
/// giorno si ricostruivano le 168 celle della griglia dentro il fotogramma
/// dell'animazione (20 ms di lavoro Dart, misurati sul telefono).
class WeekTimeline extends StatelessWidget {
  const WeekTimeline({
    super.key,
    required this.days,
    required this.width,
    required this.occurrences,
    this.todosByDay = const {},
    this.isDone,
    this.onTodo,
    this.onOpenTodo,
    this.now,
    this.onTap,
  });

  /// I giorni dell'asse, in fila: i **sette** della settimana mostrata (la
  /// settimana più la successiva era un tentativo, tolto: l'utente ha visto
  /// «due settimane invece che una»).
  final List<DateTime> days;

  /// La larghezza totale delle colonne: è più larga dello schermo, il
  /// pannamento la gestisce fuori.
  final double width;

  final List<EventOccurrence> occurrences;

  /// I todo del giorno, per giorno: quelli **con orario** si disegnano nella
  /// colonna del loro giorno, all'ora del todo (come nel giorno). Quelli senza
  /// orario stanno nella fascia sopra la griglia.
  final Map<DateTime, List<Todo>> todosByDay;

  /// Vero se il todo e' fatto **in quel giorno** (per un ricorrente e'
  /// l'occorrenza). Arriva da fuori, come nella vista giorno: la timeline non
  /// legge i provider.
  final bool Function(Todo todo, DateTime day)? isDone;

  /// Chiamato dal cerchio di una casella: spunta il todo per quel giorno.
  final void Function(Todo todo, DateTime day)? onTodo;

  /// Chiamato dal tocco sulla casella: apre il form del todo.
  final void Function(Todo todo, DateTime day)? onOpenTodo;
  final DateTime? now;
  final ValueChanged<EventOccurrence>? onTap;

  @override
  Widget build(BuildContext context) {
    const hourHeight = DayTimeline.defaultHourHeight;
    final byDay = <DateTime, List<EventOccurrence>>{};
    for (final occurrence in occurrences) {
      // Gli eventi senza orario appartengono alla fascia sopra la griglia (la
      // disegna WeekView), non a un'ora della giornata.
      if (occurrence.event.allDay) continue;
      byDay.putIfAbsent(occurrence.date, () => []).add(occurrence);
    }
    final columnWidth = width / days.length;

    return SizedBox(
      width: width,
      height: 24 * hourHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: _WeekGrid(
                width: width, hourHeight: hourHeight, columns: days.length),
          ),
          for (var index = 0; index < days.length; index++)
            Positioned(
              left: index * columnWidth,
              width: columnWidth,
              top: 0,
              height: 24 * hourHeight,
              child: WeekDayColumn(
                day: days[index],
                occurrences: byDay[days[index]] ?? const [],
                todos: todosByDay[days[index]] ?? const [],
                isDone: isDone,
                onTodo: onTodo,
                onOpenTodo: onOpenTodo,
                onTap: onTap,
              ),
            ),
          if (_indexOf(days, now) case final int today)
            Positioned(
              left: today * (columnWidth),
              width: columnWidth,
              top: _minutesOf(now!) * hourHeight / 60,
              child: const _NowBar(),
            ),
        ],
      ),
    );
  }

  /// L'indice del giorno nella settimana, o `null` se il giorno non c'è (anche
  /// `day` nullo: la linea dell'ora è opzionale).
  int? _indexOf(List<DateTime> days, DateTime? day) {
    if (day == null) return null;
    final index = days.indexWhere(
        (d) => d.year == day.year && d.month == day.month && d.day == day.day);
    return index < 0 ? null : index;
  }

  static int _minutesOf(DateTime moment) => moment.hour * 60 + moment.minute;
}

/// Le linee della griglia: orarie per tutta la larghezza, sei separatori
/// verticali fra i giorni.
class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.width,
    required this.hourHeight,
    required this.columns,
  });

  final double width;
  final double hourHeight;

  /// Quante colonne ha l'asse: si divide per questo, non per sette.
  final int columns;

  @override
  Widget build(BuildContext context) {
    final lineColor = Theme.of(context).colorScheme.outlineVariant;

    return SizedBox(
      width: width,
      height: 24 * hourHeight,
      child: Stack(
        children: [
          for (var hour = 1; hour < 24; hour++)
            Positioned(
              left: 0,
              right: 0,
              top: hour * hourHeight,
              child: Container(height: 1, color: lineColor),
            ),
          for (var i = 1; i < columns; i++)
            Positioned(
              left: i * (width / columns),
              top: 0,
              bottom: 0,
              width: 1,
              child: Container(color: lineColor),
            ),
        ],
      ),
    );
  }
}

/// La linea dell'ora corrente, dentro la colonna di oggi.
class _NowBar extends StatelessWidget {
  const _NowBar();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(height: 2, color: color);
  }
}
