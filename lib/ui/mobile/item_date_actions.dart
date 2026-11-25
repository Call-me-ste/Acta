import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/events/domain/event.dart';
import '../../features/events/event_provider.dart';
import '../../features/todos/domain/todo.dart';
import '../../features/todos/todo_provider.dart';
import '../shared/date_math.dart';
import '../shared/undo.dart';
import 'item_picking.dart';

class ItemDateActions extends StatelessWidget {
  const ItemDateActions({
    super.key,
    required this.parent,
    required this.event,
    required this.todo,
    required this.day,
  });

  final BuildContext parent;
  final Event? event;
  final Todo? todo;
  final DateTime? day;

  @override
  Widget build(BuildContext context) {
    final recurring =
        (event?.recurrenceRule ?? todo?.recurrenceRule ?? '').isNotEmpty;
    return PopupMenuButton<bool>(
      popUpAnimationStyle: menuMotion(context),
      tooltip: 'Sposta o duplica',
      onSelected: (duplicate) => _run(context, duplicate: duplicate),
      itemBuilder: (_) => [
        if (!recurring)
          const PopupMenuItem(value: false, child: Text('Sposta')),
        PopupMenuItem(
            value: true,
            child: Text(recurring ? 'Duplica una volta' : 'Duplica')),
      ],
    );
  }

  Future<void> _run(BuildContext context, {required bool duplicate}) async {
    final initial = day ?? event?.start ?? todo?.dueDate ?? DateTime.now();
    final date = await askItemDay(context, initial);
    if (date == null || !context.mounted || !parent.mounted) return;
    final VoidCallback? undo;
    if (event case final Event e) {
      undo = await _event(parent.read<EventProvider>(), e, date, duplicate);
    } else {
      undo = await _todo(parent.read<TodoProvider>(), todo!, date, duplicate);
    }
    if (!context.mounted || !parent.mounted) return;
    final message = duplicate ? 'Copia creata' : 'Data spostata';
    if (undo == null) {
      ScaffoldMessenger.of(parent)
          .showSnackBar(SnackBar(content: Text(message)));
    } else {
      showUndoSnackBar(parent, message: message, onUndo: undo);
    }
    Navigator.of(context).pop();
  }

  Future<VoidCallback?> _event(
      EventProvider provider, Event e, DateTime date, bool duplicate) async {
    final origin = day ?? e.start;
    final start = _onDay(e.start, date);
    final length = DateTime.utc(e.end.year, e.end.month, e.end.day)
        .difference(DateTime.utc(e.start.year, e.start.month, e.start.day))
        .inDays;
    final end = _onDay(e.end, date, dayOffset: length);
    if (duplicate) {
      final copy = await provider.addEvent(
        title: e.title,
        description: e.description,
        start: start,
        end: end,
        allDay: e.allDay,
        colorIndex: e.colorIndex,
        colorHex: e.colorHex,
        categoryIds: e.categoryIds,
        location: e.location,
        note: e.note,
        reminderLeads: e.reminderLeads,
        reminderSound: e.reminderSound,
      );
      return () => provider.deleteEvent(copy.id);
    }
    if (dateOnly(origin) == dateOnly(date)) return null;
    await provider.updateEvent(e.copyWith(start: start, end: end));
    return () {
      final latest =
          provider.events.where((event) => event.id == e.id).firstOrNull;
      if (latest?.start == start && latest?.end == end) {
        provider.updateEvent(latest!.copyWith(start: e.start, end: e.end));
      }
    };
  }

  Future<VoidCallback?> _todo(
      TodoProvider provider, Todo t, DateTime date, bool duplicate) async {
    if (duplicate) {
      await provider.addTodo(
        title: t.title,
        priority: t.priority,
        dueDate: date,
        startMinutes: t.startMinutes,
        endMinutes: t.endMinutes,
        categoryIds: t.categoryIds,
        colorIndex: t.colorIndex,
        location: t.location,
        note: t.note,
        reminderLeads: t.reminderLeads,
        reminderSound: t.reminderSound,
      );
      return null;
    }
    if (t.dueDate == date) return null;
    await provider.updateTodo(t.copyWith(dueDate: date));
    return () {
      final latest =
          provider.todos.where((todo) => todo.id == t.id).firstOrNull;
      if (latest?.dueDate == date) {
        provider.updateTodo(latest!.copyWith(dueDate: t.dueDate));
      }
    };
  }

  static DateTime _onDay(DateTime time, DateTime date, {int dayOffset = 0}) =>
      DateTime(date.year, date.month, date.day + dayOffset, time.hour,
          time.minute, time.second, time.millisecond, time.microsecond);
}
