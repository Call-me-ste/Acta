import 'package:flutter/material.dart';

import '../../features/todos/domain/todo.dart';
import '../../theme/design_tokens.dart';
import '../shared/due_date_label.dart';
import '../shared/event_colors.dart';
import '../shared/priority_style.dart';
import '../shared/todo_check.dart';
import '../shared/todo_time.dart';
import 'category_chips.dart';

/// La scheda di un todo: colore scelto, priorita' sul bordo, cerchio di spunta.
///
/// La priorita' si legge **senza aprire** il todo: barretta colorata sul bordo
/// sinistro piu' la pastiglia con icona e parola. Il colore dello sfondo e'
/// invece quello scelto per il todo: sono due informazioni diverse e si vedono
/// insieme.
class TodoCard extends StatelessWidget {
  const TodoCard({
    super.key,
    required this.todo,
    required this.done,
    required this.onToggle,
    required this.onTap,
    this.onLongPress,
    this.recurrence,
    this.dueOverride,
  });

  final Todo todo;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// La ricorrenza, in breve («ogni settimana»): sta sulla **stessa riga** della
  /// data, perche' due righe di contorno per un todo sono due righe di rumore.
  final String? recurrence;

  /// La data da mostrare quando non e' quella della serie: un todo ricorrente
  /// mostra la **prossima** occorrenza, non il giorno in cui la serie e'
  /// iniziata.
  final DateTime? dueOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tinta = todoColor(context, todo.colorIndex);
    final priorita = priorityColor(context, todo.priority);
    final scadenza = dueOverride ?? todo.dueDate;
    final inRitardo = !done && scadenza != null && isOverdue(scadenza);
    // L'orario si legge sulla **stessa riga** della data: per un todo bastano
    // una riga di titolo e una di contorno.
    final orario = todoTimeLabel(
      context,
      startMinutes: todo.startMinutes,
      endMinutes: todo.endMinutes,
    );

    return Material(
      key: const ValueKey('sfondo-todo'),
      // Sfondo **monocolore** per tutte le righe: la tinta al 18% rendeva
      // l'elenco sbiadito e la gerarchia poco leggibile (segnalato). Il colore
      // scelto resta sul cerchio del check — un accento, non un tinto.
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          key: const ValueKey('barretta-priorita'),
          // Il bordo sinistro invece di una barretta dentro una Row: costa un
          // conto di layout in meno ed e' alta quanto la scheda, sempre.
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: priorita, width: 5)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.s,
            AppSpacing.m,
            AppSpacing.s,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TodoCheck(done: done, onTap: onToggle, color: tinta),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            todo.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              decoration:
                                  done ? TextDecoration.lineThrough : null,
                              color: done
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        // La priorita' si dice **una volta sola**: la barretta sul
                        // bordo c'e' sempre, e per Alta e Urgente (le due che
                        // contano) si aggiunge il segno. La parola sta nel form e
                        // nei filtri, dove si sceglie: ripeterla su ogni riga era
                        // una delle cose che rendevano l'elenco rumoroso.
                        if (todo.priority >= 2)
                          Icon(
                            priorityIcon(todo.priority),
                            size: 18,
                            color: priorita,
                          ),
                      ],
                    ),
                    if (scadenza != null ||
                        recurrence != null ||
                        orario != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          if (scadenza != null) ...[
                            Icon(
                              inRitardo ? Icons.warning_amber : Icons.event,
                              size: 15,
                              color: inRitardo
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Flexible(
                            child: Text(
                              // Data e ricorrenza sulla **stessa** riga: per un
                              // todo bastano una riga di titolo e una di
                              // contorno.
                              [
                                if (scadenza != null) dueLabel(scadenza),
                                if (orario != null) orario,
                                if (recurrence != null) recurrence!,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: inRitardo
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                                fontWeight: inRitardo ? FontWeight.w700 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (todo.categoryIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child:
                            CategoryChips(ids: todo.categoryIds, dense: true),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
