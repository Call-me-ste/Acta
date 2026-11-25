import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/calendar/cluster.dart';
import '../../features/events/domain/day_layout.dart';
import '../../features/events/domain/event_occurrence.dart';
import '../../features/todos/domain/todo.dart';
import '../../theme/design_tokens.dart';
import 'cluster_badge.dart';
import 'cluster_sheet.dart';
import 'day_event_block.dart';
import 'day_hour_grid.dart';
import 'todo_compact_row.dart';

/// La griglia delle 24 ore, con gli eventi dove cadono davvero.
///
/// Due cose che una timeline "ovvia" sbaglia:
/// * un evento di 15 minuti sarebbe alto 12 px, cioè illeggibile → sotto una
///   soglia si disegna una barra con altezza minima;
/// * più di due elementi sovrapposti si spezzano in troppe corsie strette →
///   in ogni **cluster** (gli elementi che si sovrappongono a catena) si vedono
///   le prime 2 caselle per orino di inizio e il resto diventa il bollino
///   «+N», che aprendo mostra il cluster intero.
///
/// Le due regioni sono già separate e restano tali: gli eventi fanno i cluster
/// **fra loro** nella regione di sinistra, i todo fra loro nella loro colonna —
/// così un todo non finisce mai sopra un appuntamento.
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.day,
    required this.occurrences,
    this.todos = const [],
    this.onTodo,
    this.onOpenTodo,
    this.isDone,
    this.now,
    this.onTap,
    this.hourHeight = defaultHourHeight,
  });

  /// Un'ora di agenda alta così: 24 ore stanno in ~1150 px, il giusto per
  /// leggere un titolo senza che la giornata diventi un muro da scorrere.
  static const double defaultHourHeight = 48;

  /// Altezza di due righe compatte (titolo, oppure titolo + orario): è il
  /// minimo sotto cui un blocco taglierebbe il testo. Segue l'ingrandimento del
  /// testo, altrimenti a scala 1.3 una soglia fissa diventa un taglio.
  static const double _twoLineHeight = 34;

  /// La colonna delle ore a sinistra.
  static const double _gutter = AppSpacing.hourGutter;

  /// Quanto della larghezza prende la colonna dei todo **quando c'e'**: il resto
  /// resta agli eventi. 34% e' abbastanza per un titolo troncato ma leggibile.
  static const double _quotaTodo = 0.34;

  final DateTime day;
  final List<EventOccurrence> occurrences;

  /// I todo del giorno: quelli **con orario** si disegnano qui, alla loro ora.
  /// Quelli senza orario li mostra la vista, sotto la griglia.
  final List<Todo> todos;

  /// Chiamato dal cerchio di una casella: spunta il todo.
  final ValueChanged<Todo>? onTodo;

  /// Chiamato dal tocco sulle righe del foglio del cluster: apre il form del
  /// todo (gli stessi callback della vista settimana).
  final void Function(Todo todo, DateTime day)? onOpenTodo;

  /// Vero se il todo e' **fatto in questo giorno** (per un ricorrente e'
  /// l'occorrenza di quel giorno, per uno singolo e' il todo). Arriva come
  /// funzione, come [onTodo]: la timeline non legge i provider.
  final bool Function(Todo todo)? isDone;
  final DateTime? now;
  final ValueChanged<EventOccurrence>? onTap;
  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final placed = DayLayout.place(occurrences, day: day);
    // L'altezza minima scala col testo: un blocco deve poter mostrare il suo
    // contenuto senza tagliarlo.
    final minBlock =
        _twoLineHeight * MediaQuery.textScalerOf(context).scale(1.0);
    final conOrario = [
      for (final todo in todos)
        if (todo.firstTime != null) todo,
    ];

    // I cluster delle **due regioni**: gli eventi fra loro (colonna di sinistra),
    // i todo fra loro (colonna di destra): dentro un cluster ognuno ha la sua
    // corsia, e la garanzia vale fra le caselle visibili.
    final clustersEventi = clusterDi<Object>([
      for (final item in placed)
        (
          item,
          item.start.difference(dayStart).inMinutes,
          item.end.difference(dayStart).inMinutes,
        ),
    ]);
    final clustersTodo = clusterDi<Object>([
      for (final todo in conOrario) _intervalloTodo(todo),
    ]);
    final corsieEventi = corsieDeiCluster(clustersEventi);
    final corsieColonna = corsieDeiCluster(clustersTodo);

    return SizedBox(
      height: 24 * hourHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Con i todo con orario, gli eventi si stringono e a destra resta la
          // loro colonna: cosi' un todo non finisce mai **sopra** un
          // appuntamento. Senza, la griglia e' quella di sempre.
          final larghezzaEventi = conOrario.isEmpty
              ? constraints.maxWidth
              : constraints.maxWidth * (1 - _quotaTodo);
          final columnWidth = (larghezzaEventi - _gutter) / corsieEventi;
          final colonnaTodo = constraints.maxWidth * _quotaTodo;
          final laneTodo = colonnaTodo / corsieColonna;
          return Stack(
            children: [
              Positioned.fill(
                child: DayHourGrid(hourHeight: hourHeight, gutter: _gutter),
              ),
              for (final cluster in clustersEventi) ...[
                for (final (corsia, elemento) in cluster.visibili.indexed)
                  if (elemento case PlacedEvent item)
                    Positioned(
                      left: _gutter + corsia * columnWidth,
                      width: math.max(columnWidth - 6, 24),
                      top: item.offsetMinutes * hourHeight / 60,
                      height: _blockHeight(item, minBlock),
                      child: DayEventBlock(
                        occurrence: item.occurrence,
                        // Basso nella giornata: solo il titolo, l'orario non ci
                        // starebbe.
                        compact:
                            item.durationMinutes * hourHeight / 60 < minBlock,
                        onTap: onTap,
                      ),
                    ),
                if (cluster.haBollino)
                  Positioned(
                    key: ValueKey('bollino-eventi-${cluster.inizio}'),
                    left: _gutter + cluster.visibili.length * columnWidth,
                    width: math.max(columnWidth - 6, 24),
                    top: cluster.inizio * hourHeight / 60,
                    height: math.max(
                      minBlock,
                      (cluster.fine - cluster.inizio) * hourHeight / 60,
                    ),
                    child: ClusterBadge(
                      nascosti: cluster.nascosti,
                      onTap: () => _apriEventi(context, cluster),
                    ),
                  ),
              ],
              for (final cluster in clustersTodo) ...[
                for (final (corsia, elemento) in cluster.visibili.indexed)
                  if (elemento case Todo todo)
                    Positioned(
                      left: constraints.maxWidth -
                          colonnaTodo +
                          corsia * laneTodo,
                      width: laneTodo - 4,
                      top: todo.firstTime! * hourHeight / 60,
                      height: _todoHeight(todo, minBlock),
                      child: TodoCompactRow(
                        todo: todo,
                        // Le griglie sono il calendario: lo scorrimento a destra
                        // toglie il todo da qui.
                        dalCalendario: true,
                        // La colonna dei todo e' il 34% della larghezza: li' la
                        // riga sta **compatta** (barretta, cerchio, titolo).
                        compatta: true,
                        // Fatto in **questo** giorno: per un ricorrente e'
                        // l'occorrenza, per uno singolo e' il todo.
                        done: isDone?.call(todo) ?? false,
                        onToggle: onTodo == null ? () {} : () => onTodo!(todo),
                      ),
                    ),
                if (cluster.haBollino)
                  Positioned(
                    key: ValueKey('bollino-todo-${cluster.inizio}'),
                    left: constraints.maxWidth -
                        colonnaTodo +
                        cluster.visibili.length * laneTodo,
                    width: laneTodo - 4,
                    top: cluster.inizio * hourHeight / 60,
                    height: math.max(
                      minBlock,
                      (cluster.fine - cluster.inizio) * hourHeight / 60,
                    ),
                    child: ClusterBadge(
                      nascosti: cluster.nascosti,
                      onTap: () => _apriTodo(context, cluster),
                    ),
                  ),
              ],
              if (_nowIsInside(dayStart))
                Positioned(
                  left: _gutter - AppSpacing.s,
                  right: 0,
                  top: _minutesOf(now!) * hourHeight / 60,
                  child: const _NowLine(),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Il foglio del cluster degli eventi, col cluster intero.
  void _apriEventi(BuildContext context, Cluster<Object> cluster) {
    final tutti = [...cluster.visibili, ...cluster.nascosti];
    showClusterSheet(
      context,
      day: day,
      eventi: [
        for (final elemento in tutti)
          if (elemento case PlacedEvent item) item.occurrence,
      ],
      onTap: onTap,
    );
  }

  /// Idem per la colonna dei todo.
  void _apriTodo(BuildContext context, Cluster<Object> cluster) {
    final tutti = [...cluster.visibili, ...cluster.nascosti];
    showClusterSheet(
      context,
      day: day,
      todos: [
        for (final elemento in tutti)
          if (elemento case Todo todo) todo,
      ],
      onOpenTodo: onOpenTodo,
      isDone: isDone == null ? null : (todo, d) => isDone!(todo),
    );
  }

  /// L'intervallo di un todo con orario, in minuti dalla mezzanotte: limitato
  /// alla giornata e almeno di un minuto.
  static (Todo, int, int) _intervalloTodo(Todo todo) {
    final inizio = todo.firstTime!;
    final fine = math.max(
      math.min(inizio + todo.durationMinutes, 24 * 60),
      inizio + 1,
    );
    return (todo, inizio, fine);
  }

  double _blockHeight(PlacedEvent item, double minBlock) {
    return math.max(minBlock, item.durationMinutes * hourHeight / 60);
  }

  /// L'altezza della casella di un todo: **come quella di un evento della stessa
  /// durata** (un'ora quando l'orario di fine non c'e': «dalle 8» e «entro le
  /// 18» sono un'ora di spazio, la stessa casella). Sotto il minimo non si
  /// scende: quella e' l'altezza che il testo chiede.
  double _todoHeight(Todo todo, double minBlock) {
    return math.max(minBlock, todo.durationMinutes * hourHeight / 60);
  }

  bool _nowIsInside(DateTime dayStart) {
    final moment = now;
    if (moment == null) return false;
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    return moment.isAfter(dayStart) && moment.isBefore(dayEnd);
  }

  static int _minutesOf(DateTime moment) => moment.hour * 60 + moment.minute;
}

class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(child: Container(height: 2, color: color)),
      ],
    );
  }
}
