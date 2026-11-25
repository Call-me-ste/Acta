import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../features/events/domain/event_occurrence.dart';
import '../../features/todos/domain/todo.dart';
import '../../theme/design_tokens.dart';
import '../shared/event_colors.dart';
import '../shared/formatters.dart';
import '../shared/priority_style.dart';
import '../shared/todo_time.dart';
import '../shared/top_inset.dart';
import 'day_header.dart';

/// Il foglio di un **cluster**: tutti gli elementi che si sovrappongono in un
/// punto della griglia — visibili e nascosti — ciascuno con la sua fascia.
///
/// È quello che aprendo il bollino «+N» mostra cosa c'è dietro: stesso stampo
/// del foglio del colore (`isScrollControlled` + `topInset`), e gli stessi
/// callback che le viste passano già — qui nessun provider si legge.
Future<void> showClusterSheet(
  BuildContext context, {
  required DateTime day,
  List<EventOccurrence> eventi = const [],
  List<Todo> todos = const [],
  ValueChanged<EventOccurrence>? onTap,
  void Function(Todo todo, DateTime day)? onOpenTodo,
  bool Function(Todo todo, DateTime day)? isDone,
}) {
  return showActaSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height - topInset(context),
    ),
    builder: (_) => ClusterSheet(
      day: day,
      eventi: eventi,
      todos: todos,
      onTap: onTap,
      onOpenTodo: onOpenTodo,
      isDone: isDone,
    ),
  );
}

/// Il foglio vero e proprio: il titolo del giorno e le righe del cluster,
/// ordinate per inizio. Pubblico perché i test lo trovino fra i widget —
/// [showClusterSheet] resta la strada per aprirlo.
class ClusterSheet extends StatelessWidget {
  const ClusterSheet({
    super.key,
    required this.day,
    required this.eventi,
    required this.todos,
    this.onTap,
    this.onOpenTodo,
    this.isDone,
  });

  final DateTime day;
  final List<EventOccurrence> eventi;
  final List<Todo> todos;
  final ValueChanged<EventOccurrence>? onTap;
  final void Function(Todo todo, DateTime day)? onOpenTodo;
  final bool Function(Todo todo, DateTime day)? isDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Le righe si ordinano **per inizio**: il cluster si legge come una
    // timeline. Chi non ha un'ora (todo con solo la data) viene alla fine — e a
    // parità l'ordine dato resta, con un confronto di riserva sui posti.
    final voci = <(int, int, Object)>[
      for (var i = 0; i < eventi.length; i++)
        (eventi[i].start.hour * 60 + eventi[i].start.minute, i, eventi[i]),
      for (var i = 0; i < todos.length; i++)
        (todos[i].firstTime ?? 24 * 60, eventi.length + i, todos[i]),
    ]..sort((a, b) {
        final perInizio = a.$1.compareTo(b.$1);
        return perInizio != 0 ? perInizio : a.$2.compareTo(b.$2);
      });

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(DayHeader.titolo(day), style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s),
            for (final (_, _, voce) in voci)
              if (voce case EventOccurrence occurrence)
                _RigaEvento(
                  occurrence: occurrence,
                  onTap: onTap == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          onTap!(occurrence);
                        },
                )
              else if (voce case Todo todo)
                _RigaTodo(
                  todo: todo,
                  day: day,
                  done: isDone?.call(todo, day) ?? false,
                  onTap: onOpenTodo == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          onOpenTodo!(todo, day);
                        },
                ),
          ],
        ),
      ),
    );
  }
}

/// Un evento nel foglio: la stessa tinta del blocco (alpha 0.32) e la sua
/// fascia oraria — «Tutto il giorno» per chi un'ora non ce l'ha.
class _RigaEvento extends StatelessWidget {
  const _RigaEvento({required this.occurrence, this.onTap});

  final EventOccurrence occurrence;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fascia = occurrence.event.allDay
        ? 'Tutto il giorno'
        : formatTimeRange(occurrence.start, occurrence.end);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.bar),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: occurrenceColor(context, occurrence).withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(AppRadius.bar),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                occurrence.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Text(
              fascia,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un todo nel foglio: la barretta della priorità come nella riga compatta,
/// l'orario come si legge ovunque («dalle 08:00», «entro le 18:00») e il
/// titolo barrato quando è fatto. Senza orario, nessuna fascia.
class _RigaTodo extends StatelessWidget {
  const _RigaTodo({
    required this.todo,
    required this.day,
    required this.done,
    this.onTap,
  });

  final Todo todo;
  final DateTime day;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fascia = todoTimeLabel(
      context,
      startMinutes: todo.startMinutes,
      endMinutes: todo.endMinutes,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.bar),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.bar),
          border: Border(
            left: BorderSide(
              color: priorityColor(context, todo.priority),
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                todo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? scheme.onSurfaceVariant : null,
                ),
              ),
            ),
            if (fascia != null) ...[
              const SizedBox(width: AppSpacing.s),
              Text(
                fascia,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
