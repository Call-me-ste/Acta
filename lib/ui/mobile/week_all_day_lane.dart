import 'package:flutter/material.dart';

import '../../features/calendar/cluster.dart';
import '../../features/events/domain/event_occurrence.dart';
import '../../features/todos/domain/todo.dart';
import '../shared/event_colors.dart';
import '../shared/priority_style.dart';
import '../../theme/design_tokens.dart';
import 'cluster_badge.dart';
import 'cluster_sheet.dart';

/// La fascia degli eventi **senza orario** della settimana — e dei todo senza
/// orario, che di una giornata non hanno un'ora: una cella per giorno, con le
/// prime due caselle del cluster + il bollino «+N» degli altri.
///
/// Qui tutti gli elementi di un giorno si sovrappongono **per definizione**
/// (nessuno ha un'ora): il cluster del giorno è l'intera cella, e il «+N» — che
/// prima era una scritta morta — apre il foglio col cluster intero, stesso
/// stile e stessa regola di colore delle griglie delle ore.
///
/// La larghezza arriva da fuori (pannata in sync con la griglia): ogni cella è
/// larga esattamente `width / giorni`.
class WeekAllDayLane extends StatelessWidget {
  const WeekAllDayLane({
    super.key,
    required this.days,
    required this.width,
    required this.byDay,
    this.todoByDay = const {},
    this.onTap,
    this.onTodo,
    this.isDone,
  });

  final List<DateTime> days;
  final double width;
  final Map<DateTime, List<EventOccurrence>> byDay;
  final ValueChanged<EventOccurrence>? onTap;

  /// I todo **senza orario** del giorno: in «Pieni» stanno qui, perche' nella
  /// griglia delle ore non hanno un posto dove stare.
  final Map<DateTime, List<Todo>> todoByDay;

  /// Il tocco su un todo: apre il form (è `WeekView` che passa `onOpenTodo`,
  /// come per le caselle).
  final void Function(Todo todo, DateTime day)? onTodo;
  final bool Function(Todo todo, DateTime day)? isDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days)
          SizedBox(
            width: width / days.length,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: _cella(context, theme, day),
              ),
            ),
          ),
      ],
    );
  }

  /// Il contenuto di una cella: le prime due caselle del cluster del giorno e,
  /// se ce ne sono altri, il bollino. Gli intervalli sono tutti uguali (0, 1):
  /// senza un'ora, ogni elemento tocca ogni altro → un cluster solo.
  List<Widget> _cella(BuildContext context, ThemeData theme, DateTime day) {
    final cluster = clusterDi<Object>([
      for (final occurrence in byDay[day] ?? const <EventOccurrence>[])
        (occurrence, 0, 1),
      for (final todo in todoByDay[day] ?? const <Todo>[]) (todo, 0, 1),
    ]);
    if (cluster.isEmpty) return const [];
    final singolo = cluster.single;

    return [
      for (final elemento in singolo.visibili)
        if (elemento case EventOccurrence occurrence)
          _chipEvento(context, theme, day, occurrence)
        else if (elemento case Todo todo)
          _chipTodo(context, theme, day, todo),
      if (singolo.haBollino)
        ClusterBadge(
          key: const ValueKey('bollino-fascia'),
          nascosti: singolo.nascosti,
          onTap: () => _apriCluster(context, day),
        ),
    ];
  }

  /// Il foglio del cluster: tutti gli elementi senza orario del giorno, che è
  /// esattamente il cluster (visibili e nascosti).
  void _apriCluster(BuildContext context, DateTime day) {
    showClusterSheet(
      context,
      day: day,
      eventi: byDay[day] ?? const [],
      todos: todoByDay[day] ?? const [],
      onTap: onTap,
      onOpenTodo: onTodo,
      isDone: isDone,
    );
  }

  Widget _chipEvento(
    BuildContext context,
    ThemeData theme,
    DateTime day,
    EventOccurrence occurrence,
  ) =>
      InkWell(
        onTap: onTap == null ? null : () => onTap!(occurrence),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: occurrenceColor(context, occurrence).withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(AppRadius.bar),
          ),
          child: Text(
            occurrence.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: AppType.micro,
              height: 1.2,
            ),
          ),
        ),
      );

  /// I chip dei todo senza orario: barretta della priorita' davanti (e' quello
  /// che li distingue dagli eventi) e titolo barrato se fatto.
  Widget _chipTodo(
    BuildContext context,
    ThemeData theme,
    DateTime day,
    Todo todo,
  ) =>
      InkWell(
        onTap: onTodo == null ? null : () => onTodo!(todo, day),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.bar),
            border: Border(
              left: BorderSide(
                color: priorityColor(context, todo.priority),
                width: 3,
              ),
            ),
          ),
          child: Text(
            todo.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: AppType.micro,
              height: 1.2,
              decoration: (isDone?.call(todo, day) ?? false)
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
      );
}
