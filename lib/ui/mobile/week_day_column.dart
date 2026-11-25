import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/calendar/cluster.dart';
import '../../features/events/domain/day_layout.dart';
import '../../features/events/domain/event_occurrence.dart';
import '../../features/todos/domain/todo.dart';
import 'cluster_badge.dart';
import 'cluster_sheet.dart';
import 'day_timeline.dart';
import 'todo_compact_row.dart';
import 'week_event_block.dart';

/// Una colonna della settimana: gli eventi del giorno e i loro todo, in una
/// **cascata di cluster** invece che in corsie per l'intera giornata.
///
/// Il contratto in settimana: **due riquadri al massimo** — tre affiancati non
/// si leggono (segnalato: «mi piace solo quando ce ne sono 2 accanto»). Con
/// due o meno elementi si vedono le loro caselle (le prime 2 per orino di
/// inizio); con più di due il primo elemento resta casella e il **secondo
/// riquadro diventa il bollino «+N»** — stessa grafica, stessa corsia, conto
/// = gli elementi oltre il primo — e aprendo il foglio mostra il cluster
/// intero. Eventi e todo condividono i riquadri: un todo con orario è un
/// impegno a quell'ora come gli altri (era la segnalazione «si compenetrano»).
///
/// La larghezza è **del cluster**, non del giorno: un elemento da solo occupa
/// tutta la colonna (un cluster «+N» più in basso non lo stringe), due si
/// dividono la colonna a metà, e le corsie si ricominciano da zero in ogni
/// cluster — i cluster sono disgiunti nel tempo, quindi non collidono. Sta in
/// un file suo per il tetto delle 300 righe di `week_timeline.dart`.
class WeekDayColumn extends StatelessWidget {
  const WeekDayColumn({
    super.key,
    required this.day,
    required this.occurrences,
    this.todos = const [],
    this.isDone,
    this.onTodo,
    this.onOpenTodo,
    this.onTap,
  });

  final DateTime day;
  final List<EventOccurrence> occurrences;

  /// I todo del giorno: quelli **con orario** stanno nella colonna alla loro
  /// ora; i senza orario li disegna la fascia sopra la griglia.
  final List<Todo> todos;

  final bool Function(Todo todo, DateTime day)? isDone;
  final void Function(Todo todo, DateTime day)? onTodo;
  final void Function(Todo todo, DateTime day)? onOpenTodo;
  final ValueChanged<EventOccurrence>? onTap;

  /// Un blocco basso non è illeggibile: sotto questa altezza il testo non ci
  /// sta (scala col testo, come nella vista giorno).
  static const double minBlockHeight = 20;

  @override
  Widget build(BuildContext context) {
    const hourHeight = DayTimeline.defaultHourHeight;
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final dayStart = DateTime(day.year, day.month, day.day);
    // Gli all-day non entrano: li disegna la fascia sopra la griglia (li ha già
    // separati chi costruisce la colonna).
    final placed = DayLayout.place(occurrences, day: day);
    final conOrario = [
      for (final todo in todos)
        if (todo.firstTime != null) todo,
    ];

    // Le due caselle sono **condivise**: eventi e todo entrano nello stesso
    // cluster e il bollino conta il resto. A parità di inizio vince l'ordine
    // dato — prima gli eventi (già ordinati da `place`), poi i todo.
    final clusters = clusterDi<Object>([
      for (final item in placed)
        (
          item,
          item.start.difference(dayStart).inMinutes,
          item.end.difference(dayStart).inMinutes,
        ),
      for (final todo in conOrario) _intervalloTodo(todo),
    ]);

    return LayoutBuilder(
      builder: (context, constraints) {
        // La larghezza è **del cluster**: chi è solo tiene la colonna intera,
        // chi è in due se la divide — e il vicino non c'entra (era il bug:
        // un cluster «+N» più in basso stringeva a metà anche quello sopra).
        double laneDi(Cluster<Object> cluster) =>
            constraints.maxWidth / cluster.visibili.length;
        return Stack(
          children: [
            for (final cluster in clusters) ...[
              // Con più di due elementi resta il primo: il secondo riquadro è
              // del bollino, che viene subito dopo.
              for (final (corsia, elemento) in (cluster.haBollino
                      ? [cluster.visibili.first]
                      : cluster.visibili)
                  .indexed)
                if (elemento case PlacedEvent item)
                  Positioned(
                    left: corsia * laneDi(cluster) + 1,
                    width: laneDi(cluster) - 2,
                    top: item.offsetMinutes * hourHeight / 60,
                    height: math.max(
                      minBlockHeight * scale,
                      item.durationMinutes * hourHeight / 60,
                    ),
                    child: WeekEventBlock(
                      occurrence: item.occurrence,
                      // L'orario è informazione nei blocchi alti, rumore nei
                      // brevi.
                      showTime: item.durationMinutes >= 30,
                      onTap: onTap,
                    ),
                  )
                else if (elemento case Todo todo)
                  Positioned(
                    left: corsia * laneDi(cluster) + 1,
                    width: laneDi(cluster) - 2,
                    top: todo.firstTime! * hourHeight / 60,
                    height: math.max(
                      minBlockHeight * scale,
                      todo.durationMinutes * hourHeight / 60,
                    ),
                    child: GestureDetector(
                      onTap: onOpenTodo == null
                          ? null
                          : () => onOpenTodo!(todo, day),
                      child: TodoCompactRow(
                        todo: todo,
                        done: isDone?.call(todo, day) ?? false,
                        dalCalendario: true,
                        // Colonna stretta: riga compatta, come nel giorno.
                        compatta: true,
                        onToggle:
                            onTodo == null ? () {} : () => onTodo!(todo, day),
                      ),
                    ),
                  ),
              if (cluster.haBollino)
                Positioned(
                  key: ValueKey('bollino-${cluster.inizio}'),
                  // Il **secondo** riquadro, con la grafica delle caselle.
                  left: laneDi(cluster) + 1,
                  width: laneDi(cluster) - 2,
                  top: cluster.inizio * hourHeight / 60,
                  height: math.max(
                    minBlockHeight * scale,
                    (cluster.fine - cluster.inizio) * hourHeight / 60,
                  ),
                  child: ClusterBadge(
                    // Tutto ciò che non è il primo riquadro: il secondo
                    // elemento messo da parte e i nascosti — il conto dice
                    // quanti elementi ci sono oltre il primo (cluster da 4 →
                    // «+3»).
                    nascosti: [
                      ...cluster.visibili.skip(1),
                      ...cluster.nascosti,
                    ],
                    onTap: () => _apriCluster(context, cluster),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  /// Apre il foglio col **cluster intero**: visibili e nascosti, ciascuno con
  /// la sua fascia. Gli stessi callback della vista, nessun provider qui.
  void _apriCluster(BuildContext context, Cluster<Object> cluster) {
    final tutti = [...cluster.visibili, ...cluster.nascosti];
    showClusterSheet(
      context,
      day: day,
      eventi: [
        for (final elemento in tutti)
          if (elemento case PlacedEvent item) item.occurrence,
      ],
      todos: [
        for (final elemento in tutti)
          if (elemento case Todo todo) todo,
      ],
      onTap: onTap,
      onOpenTodo: onOpenTodo,
      isDone: isDone == null ? null : (todo, d) => isDone!(todo, d),
    );
  }

  /// L'intervallo di un todo con orario, in minuti dalla mezzanotte: limitato
  /// alla giornata (un blocco che esce dalla griglia non si capisce) e almeno di
  /// un minuto.
  static (Todo, int, int) _intervalloTodo(Todo todo) {
    final inizio = todo.firstTime ?? 0;
    final fine = math.max(
      math.min(inizio + todo.durationMinutes, 24 * 60),
      inizio + 1,
    );
    return (todo, inizio, fine);
  }
}
