import 'package:flutter/material.dart';

import '../../features/calendar/agenda_days.dart';
import '../../theme/design_tokens.dart';
import 'agenda_day_group.dart';

/// Keeps each build bounded even when a single date has hundreds of entries.
class AgendaList extends StatelessWidget {
  const AgendaList({super.key, required this.days, this.today});

  final List<GiornoDellAgenda> days;
  final DateTime? today;
  static const _chunkSize = 8;

  @override
  Widget build(BuildContext context) {
    final chunks = [
      for (final day in days)
        for (var offset = 0;
            offset < day.eventi + day.todos.length;
            offset += _chunkSize)
          (day: day, offset: offset),
    ];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      itemCount: chunks.length,
      itemBuilder: (context, index) {
        final (:day, :offset) = chunks[index];
        final end = offset + _chunkSize;
        final continues = end < day.eventi + day.todos.length;
        return Padding(
          padding: EdgeInsets.only(bottom: continues ? 0 : AppSpacing.m),
          child: AgendaDayGroup(
            day: day.day,
            allDay: _slice(day.allDay, offset, end),
            timed: _slice(
                day.timed, offset - day.allDay.length, end - day.allDay.length),
            todos: _slice(day.todos, offset - day.eventi, end - day.eventi),
            oggi: today,
            showHeader: offset == 0,
            hasContinuation: continues,
          ),
        );
      },
    );
  }

  static List<T> _slice<T>(List<T> list, int start, int end) {
    final first = start.clamp(0, list.length);
    final last = end.clamp(0, list.length);
    if (first == 0 && last == list.length) return list;
    return list.sublist(first, last);
  }
}
