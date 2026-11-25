import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/todos/domain/todo.dart';
import '../../features/todos/todo_hidden.dart';
import '../../features/todos/todo_provider.dart';
import '../../theme/design_tokens.dart';
import '../shared/event_colors.dart';
import '../shared/feedback.dart';
import '../shared/priority_style.dart';
import '../shared/todo_check.dart';
import '../shared/todo_time.dart';
import '../shared/undo.dart';
import 'calendar_todo_card.dart';

/// La riga **compatta** di un todo: quella delle viste dove il todo non e' il
/// protagonista (la striscia del giorno, la sezione sotto il mese).
///
/// Dice le stesse cose della scheda — barretta della priorita', cerchio di
/// spunta, priorita' scritta — in meno spazio. Una sola implementazione perche'
/// se le due forme dicessero cose diverse, la stessa priorita' si leggerebbe in
/// due modi.
///
/// **Fatto** si vede come nella scheda: titolo barrato, testo attenuato e cerchio
/// pieno. Un todo fatto resta in calendario finche' non lo si toglie di
/// proposito: e' [dalCalendario] a dare lo scorrimento a destra che mette il
/// segno «via dal calendario», con l'annulla (nella scheda Todo e in agenda la
/// riga non ha quel gesto: li' il todo resta).
class TodoCompactRow extends StatelessWidget {
  const TodoCompactRow({
    super.key,
    required this.todo,
    required this.onToggle,
    this.done = false,
    this.dalCalendario = false,
    this.compatta = false,
    this.card = false,
    this.onOpen,
  });

  final Todo todo;
  final VoidCallback onToggle;

  /// Vero se il todo e' fatto **in questo giorno** (per un ricorrente e'
  /// l'occorrenza, per uno singolo e' il todo: lo dice `isDoneOn`).
  final bool done;

  /// Vero quando la riga sta **nel calendario**, dove lo scorrimento a destra
  /// toglie il todo dalle griglie (e l'avviso lo rimette).
  final bool dalCalendario;

  /// Vero per la **scheda del calendario**: stessa forma di un evento (barra,
  /// titolo, orario sotto), con la spunta e la priorità in più. Il tocco apre
  /// il dettaglio.
  final bool card;

  /// Apre il dettaglio; serve solo nella variante [card].
  final VoidCallback? onOpen;

  /// Vero per la **cella della griglia** delle ore: la scritta occupa tutto lo
  /// spazio come in un evento (micro w500, ellissi, orario sotto quando la
  /// casella e' alta) e il **pallino non c'e'**: in una cella cosi' stretta
  /// mangiava il titolo («non si legge nulla», segnalato). Il colore resta quello
  /// del todo e la barretta della priorita' pure — si spunta nella striscia,
  /// nella sezione, nella scheda o aprendo il todo.
  ///
  /// Non si decide **misurando**: la riga vive anche dentro un `IntrinsicHeight`
  /// (il gruppo del giorno in agenda), e un `LayoutBuilder` li' dentro non sa
  /// dire le misure intrinseche.
  final bool compatta;

  @override
  Widget build(BuildContext context) {
    final riga = _riga(context);
    if (!dalCalendario) return riga;

    final todo = this.todo;
    final todos = context.read<TodoProvider>();

    return Dismissible(
      // La chiave e' l'id del todo: nella stessa lista un todo compare una volta
      // sola (un ricorrente sta nella striscia del suo giorno).
      key: ValueKey('via-calendario-${todo.id}'),
      direction: DismissDirection.startToEnd,
      background: _SfondoViaDalCalendario(done: done),
      onDismissed: (_) {
        tickFeedback();
        todos.hideFromCalendar(todo);
        showUndoSnackBar(
          context,
          message: 'Fuori dal calendario',
          onUndo: () => todos.showInCalendar(todo),
        );
      },
      child: riga,
    );
  }

  Widget _riga(BuildContext context) {
    // La cella della griglia e' un disegno suo: vedi [_casella].
    if (compatta) return _casella(context);
    if (card) {
      return CalendarTodoCard(
        todo: todo,
        done: done,
        onToggle: onToggle,
        onOpen: onOpen,
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // L'orario, quando c'e', e' la cosa che dice se un todo e' «adesso» o
    // «dopo»: sta a **destra**, accanto alla priorita'.
    final orario = todoTimeLabel(
      context,
      startMinutes: todo.startMinutes,
      endMinutes: todo.endMinutes,
    );
    final attenuato = scheme.onSurfaceVariant;
    final tinta =
        todoColor(context, todo.colorIndex) ?? scheme.surfaceContainerHigh;

    final titolo = Text(
      todo.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        decoration: done ? TextDecoration.lineThrough : null,
        color: done ? attenuato : null,
      ),
    );
    final quando = orario == null
        ? null
        : Text(
            orario,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: attenuato),
          );

    return Material(
      // La **casella**: la stessa altezza e lo stesso raggio di quella di un
      // evento (una riga di testo piu' 8 di respiro), con la tinta **tenue** del
      // colore del todo. Quello che la distingue da un evento non e' la forma ma
      // il contenuto: la barretta della priorita' e il cerchio di spunta, che un
      // evento non ha. Fatta, si sbiadisce invece di sparire.
      color: tinta.withValues(alpha: done ? 0.10 : 0.20),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        // Nella variante compatta il respiro e' meta': la colonna della griglia e'
        // stretta e quei pixel servono al titolo.
        padding: EdgeInsets.symmetric(
          horizontal: compatta ? AppSpacing.s : AppSpacing.m,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 26,
              decoration: BoxDecoration(
                color: priorityColor(context, todo.priority),
                borderRadius: BorderRadius.circular(AppRadius.bar),
              ),
            ),
            SizedBox(width: compatta ? 4 : AppSpacing.s),
            TodoCheck(
              done: done,
              size: compatta ? 16 : 22,
              color: todoColor(context, todo.colorIndex),
              onTap: onToggle,
            ),
            SizedBox(width: compatta ? 4 : AppSpacing.s),
            Expanded(child: titolo),
            if (!compatta && quando != null) ...[
              const SizedBox(width: AppSpacing.s),
              quando,
            ],
            if (!compatta && todo.priority > 0)
              PriorityChip(priority: todo.priority, compact: true),
          ],
        ),
      ),
    );
  }

  /// La **cella della griglia**: barretta e colore del todo, il titolo a tutta
  /// larghezza col trattamento degli eventi e l'orario sotto quando la casella
  /// e' abbastanza alta (lo stesso criterio dei blocchi evento). Niente cerchio:
  /// qui non ci sta e mangiava il titolo.
  Widget _casella(BuildContext context) {
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
      // Lo stesso colore di prima: la tinta **tenue** del todo, piu' scura se
      // fatto — solo il pallino e' sparito, non il colore.
      color: tinta.withValues(alpha: done ? 0.10 : 0.20),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: Row(
          // La barretta riempie l'altezza della cella: una cella da 24 px non
          // puo' contenerne 26 scritti a mano.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: priorityColor(context, todo.priority),
                borderRadius: BorderRadius.circular(AppRadius.bar),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    todo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: AppType.micro,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  if (orario != null && todo.durationMinutes >= 30)
                    Text(
                      orario,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: AppType.nano,
                        height: 1.1,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lo sfondo che si scopre scorrendo a destra: dice **dove** finira' il todo
/// («fuori dal calendario», non «cancellato»: nella scheda Todo resta).
class _SfondoViaDalCalendario extends StatelessWidget {
  const _SfondoViaDalCalendario({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: AppSpacing.s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            // Un todo fatto se ne va con la sua spunta: e' finito.
            done ? Icons.check_circle_outline : Icons.visibility_off_outlined,
            size: AppSpacing.iconSmall,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.s),
          Text(
            'Fuori dal calendario',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
