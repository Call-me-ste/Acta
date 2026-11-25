import 'package:flutter/material.dart';

import '../../features/todos/domain/todo.dart';
import '../../theme/design_tokens.dart';
import '../shared/event_colors.dart';
import '../shared/priority_style.dart';
import '../shared/todo_check.dart';
import '../shared/todo_time.dart';

/// La **scheda del calendario** di un todo: la stessa forma di un evento — barra
/// colorata, titolo, orario sotto — con in più la spunta e la priorità.
///
/// L'orario sta sotto il titolo, con un respiro: prima era appiccicato sulla
/// stessa riga e la scheda sembrava un elenco compresso. Il tocco apre il
/// dettaglio, la spunta resta un bersaglio a sé.
class CalendarTodoCard extends StatelessWidget {
  const CalendarTodoCard({
    super.key,
    required this.todo,
    required this.done,
    required this.onToggle,
    this.onOpen,
  });

  final Todo todo;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tinta =
        todoColor(context, todo.colorIndex) ?? scheme.surfaceContainerHigh;
    final orario = todoTimeLabel(
      context,
      startMinutes: todo.startMinutes,
      endMinutes: todo.endMinutes,
    );

    return Material(
      color: tinta.withValues(alpha: done ? 0.10 : 0.16),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 34,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: priorityColor(context, todo.priority),
                  borderRadius: BorderRadius.circular(AppRadius.bar),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              TodoCheck(
                done: done,
                size: 22,
                color: todoColor(context, todo.colorIndex),
                onTap: onToggle,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                    if (orario != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        orario,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (todo.priority > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                PriorityChip(priority: todo.priority, compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
