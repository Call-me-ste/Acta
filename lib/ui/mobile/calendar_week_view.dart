import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/calendar/day_axis.dart';
import '../../features/events/event_provider.dart';
import '../../features/filters/filtro_condiviso.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/todos/todo_recurrence.dart';
import '../../features/todos/todo_windows.dart';
import 'calendar_jumps.dart';
import 'calendar_view_cache.dart';
import 'item_detail_sheet.dart';
import 'week_view.dart';

/// La vista settimana, estratta da `calendar_page.dart` per rispettare il tetto
/// di 300 righe. Riceve dallo stato della pagina solo cio' che le serve: il
/// giorno scelto, la memoria delle viste e i callback di navigazione.
Widget buildCalendarWeek({
  required BuildContext context,
  required AppSettingsController settings,
  required Object generazione,
  required FiltroCondiviso filtro,
  required DateTime selectedDay,
  required CalendarViewCache viste,
  required ValueChanged<DateTime> onSelectDay,
  required ValueChanged<DateTime> onOpenDay,
  required VoidCallback onPreviousWeek,
  required VoidCallback onNextWeek,
  required VoidCallback onPickMonth,
}) {
  final modo = settings.todoInCalendario;

  return viste.vista(
    CalendarViewCache.settimana,
    settings.calendarView == CalendarView.settimana,
    (generazione, selectedDay, modo, filtro.firma),
    () {
      final eventProvider = context.read<EventProvider>();
      final todoProvider = context.read<TodoProvider>();
      final start = DayAxis.mondayOf(selectedDay);
      // Tanti giorni quanti ne ha l'asse della vista (`WeekView.giorniAsse`):
      // chiedendone sette, le colonne in piu' restavano vuote.
      final end = CalendarJumps.piuGiorni(start, DayAxis.giorniAsseSettimana);
      // I todo della settimana: **una passata sola** (come il mese) e il filtro
      // applicato dove si leggono.
      final perGiorno = todoProvider.todoDelCalendario(start, end, filtro);
      return WeekView(
        weekStart: start,
        selectedDay: selectedDay,
        occurrences: filtro.filtraEventi(
          eventProvider.occurrencesBetween(start, end),
        ),
        todos: (perGiorno: perGiorno, modo: modo),
        isDone: todoProvider.isDoneOn,
        onTodo: todoProvider.toggleForDay,
        // Il tocco su una casella di todo apre il form, come per un evento.
        onOpenTodo: (todo, day) => showItemDetail(
          context,
          todo: todo,
          day: todo.dueDate ?? day,
        ),
        now: DateTime.now(),
        onTap: (occurrence) => showItemDetail(
          context,
          event: occurrence.event,
          day: occurrence.date,
        ),
        onDaySelected: onSelectDay,
        onOpenDay: onOpenDay,
        onPreviousWeek: onPreviousWeek,
        onNextWeek: onNextWeek,
        // Dalla settimana si sceglie la settimana, non il mese.
        onPickMonth: onPickMonth,
      );
    },
  );
}



