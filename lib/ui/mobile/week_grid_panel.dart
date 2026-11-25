import 'package:flutter/material.dart';

import '../../features/events/domain/event_occurrence.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/domain/todo.dart';
import '../../theme/design_tokens.dart';
import 'day_timeline.dart';
import 'hour_labels.dart';
import 'week_timeline_cache.dart';

/// La **griglia** della settimana: la colonna degli orari fissa a sinistra, le
/// colonne dei giorni che si pannano in orizzontale, la tinta del giorno scelto
/// sotto la griglia ricordata.
///
/// Sta in un file suo per il tetto di righe di `week_view.dart`, che resta il
/// posto del *collegamento* fra i tre pannelli (intestazioni, fascia, griglia) —
/// e non di come si disegna una giornata.
class WeekGridPanel extends StatelessWidget {
  const WeekGridPanel({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.columnsWidth,
    required this.columnWidth,
    required this.occurrences,
    required this.todos,
    required this.timeline,
    required this.vScroll,
    required this.gridPan,
    this.now,
    this.onTap,
    this.onTodo,
    this.onOpenTodo,
    this.isDone,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final double columnsWidth;
  final double columnWidth;
  final List<EventOccurrence> occurrences;
  final ({Map<DateTime, List<Todo>> perGiorno, TodoInCalendario modo}) todos;
  final WeekTimelineCache timeline;

  /// Lo scorrimento **verticale** (condiviso con la colonna degli orari) e quello
  /// orizzontale della griglia (sincronizzato con intestazioni e fascia).
  final ScrollController vScroll;
  final ScrollController gridPan;

  final DateTime? now;
  final ValueChanged<EventOccurrence>? onTap;
  final void Function(Todo todo, DateTime day)? onTodo;
  final void Function(Todo todo, DateTime day)? onOpenTodo;
  final bool Function(Todo todo, DateTime day)? isDone;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: vScroll,
      padding: const EdgeInsets.only(
        bottom: AppSpacing.calendarActionsClearance,
      ),
      child: SizedBox(
        height: 24 * DayTimeline.defaultHourHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: HourLabels.width, child: HourLabels()),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: gridPan,
                child: SizedBox(
                  width: columnsWidth,
                  // Due livelli: la tinta del giorno scelto **sotto**, la griglia
                  // sopra. La tinta è l'unica cosa che cambia cambiando giorno, e
                  // sta fuori dalla timeline ricordata: è il motivo per cui
                  // cambiare giorno adesso costa poco.
                  child: Stack(
                    children: [
                      if (_indiceScelto(days) case final int scelto)
                        Positioned(
                          key: const ValueKey('tinta-giorno'),
                          left: scelto * columnWidth,
                          width: columnWidth,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                      timeline.costruisci(
                        giorni: days,
                        larghezza: columnsWidth,
                        occurrences: occurrences,
                        // I todo entrano nella chiave della memoria per **modo**:
                        // i todo in sé cambiano solo quando cambia la generazione,
                        // e quella è già nella chiave della vista.
                        chiaveTodo: todos.modo,
                        todosByDay: todos.modo == TodoInCalendario.pieni
                            ? todos.perGiorno
                            : const {},
                        isDone: isDone,
                        onTodo: onTodo,
                        onOpenTodo: onOpenTodo,
                        now: now,
                        onTap: onTap,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// L'indice del giorno scelto nella fila dei giorni, o `null` se non c'è.
  int? _indiceScelto(List<DateTime> giorni) {
    final indice = giorni.indexWhere(
      (giorno) =>
          giorno.year == selectedDay.year &&
          giorno.month == selectedDay.month &&
          giorno.day == selectedDay.day,
    );
    return indice < 0 ? null : indice;
  }
}
