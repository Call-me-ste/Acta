import 'package:flutter/material.dart';

import '../../features/events/domain/day_layout.dart';
import '../../features/events/domain/event_occurrence.dart';
import '../../features/todos/domain/todo.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import '../shared/event_colors.dart';
import '../shared/priority_style.dart';

/// Il bollino di un cluster, in **due parti** — i due tipi si contano e si
/// colorano a modo loro:
///
/// * gli **eventi nascosti**: «+E» sul riquadro, col **colore dell'evento**
///   (lo stesso tint dei blocchi);
/// * i **todo nascosti**: un **pallino tondo** «+T» con l'interno del **colore
///   del todo** — quello scelto, con la priorità da fallback quando il todo non
///   ne ha uno.
///
/// Il tocco (su tutta l'area) apre il foglio del cluster: qui stanno solo i
/// conti e i colori, il foglio lo apre chi sa quali elementi ci mettere.
class ClusterBadge extends StatelessWidget {
  const ClusterBadge({
    super.key,
    required this.nascosti,
    required this.onTap,
  });

  /// Gli elementi nascosti del cluster: da loro vengono i due conteggi e i
  /// due colori.
  final List<Object> nascosti;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var eventi = 0;
    EventOccurrence? primoEvento;
    final todos = <Todo>[];
    for (final elemento in nascosti) {
      if (elemento case PlacedEvent item) {
        eventi++;
        primoEvento ??= item.occurrence;
      } else if (elemento case EventOccurrence occorrenza) {
        eventi++;
        primoEvento ??= occorrenza;
      } else if (elemento case Todo todo) {
        todos.add(todo);
      }
    }

    // Il riquadro prende il colore dell'evento nascosto (lo stesso tint dei
    // blocchi); senza eventi resta neutro e il pallino fa da tutto.
    final sfondo = primoEvento == null
        ? theme.colorScheme.surfaceContainerHigh
        : occurrenceColor(context, primoEvento).withValues(alpha: 0.32);

    final parti = [
      if (eventi > 0) '+$eventi eventi',
      if (todos.isNotEmpty) '+${todos.length} To do',
    ];

    return Semantics(
      button: true,
      label: '${parti.join(' e ')} nascosti',
      // Senza, il testo dei `Text` si unisce all'etichetta e la leggibilità per
      // uno screen reader diventa un aborto di «+1+2».
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.bar),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: sfondo,
            borderRadius: BorderRadius.circular(AppRadius.bar),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (eventi > 0)
                Text(
                  '+$eventi',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppType.micro,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              if (eventi > 0 && todos.isNotEmpty)
                const SizedBox(width: AppSpacing.xs),
              if (todos.isNotEmpty) _pallinoTodo(context, todos),
            ],
          ),
        ),
      ),
    );
  }

  /// Il pallino dei todo nascosti: tondo, con **l'interno del colore del todo**
  /// (il colore scelto; la priorità da fallback) e il conto dentro.
  Widget _pallinoTodo(BuildContext context, List<Todo> todos) {
    final theme = Theme.of(context);
    final primo = todos.first;
    final interno = todoColor(context, primo.colorIndex) ??
        priorityColor(context, primo.priority);
    // `CircleAvatar` e non un Container: il pallino e' un cerchio a sé, e i
    // test lo cercano per tipo senza ambiguity con il riquadro.
    return CircleAvatar(
      radius: 11,
      backgroundColor: interno,
      child: Text(
        '+${todos.length}',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: AppType.nano,
          fontWeight: FontWeight.w500,
          height: 1.1,
          color: ColorResolver.onColor(interno),
        ),
      ),
    );
  }
}
