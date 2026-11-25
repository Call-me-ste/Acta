import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/recurrence/domain/recurrence_label.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../features/todos/todo_entry.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/todos/todo_recurrence.dart';
import '../../features/todos/todo_selection.dart';
import '../../theme/design_tokens.dart';
import '../shared/feedback.dart';
import '../shared/undo.dart';
import 'item_detail_sheet.dart';
import 'todo_card.dart';

/// Una riga dell'elenco: la scheda del todo, piu' i gesti.
///
/// I gesti sono due, e fanno cose diverse: a destra si **spunta** (il gesto piu'
/// frequente, come nelle app di riferimento), a sinistra si cancella. Il tocco
/// prolungato **apre la selezione multipla** (#90): prima cancellava, ma la
/// cancellazione ce l'ha lo scorrimento e adesso c'e' una strada con l'annulla
/// anche per chi non scorre.
///
/// Con la selezione aperta i gesti di scorrimento si spengono: mentre si sceglie,
/// un dito che scorre non deve spuntare o cancellare niente. Il tocco (sulla riga
/// o sul cerchio) mette dentro o fuori dalla selezione.
///
/// Sta in un file suo perche' la pagina ha un budget di righe da rispettare
/// (`test/architecture_test.dart`): si estrae, non si alza.
class TodoTile extends StatelessWidget {
  const TodoTile({super.key, required this.entry});

  final TodoEntry entry;

  @override
  Widget build(BuildContext context) {
    // Un `Selector` e non un `watch`: la selezione cambia a ogni tocco, e un
    // `watch` ricostruirebbe **tutte** le righe per cambiarne una (con l'agenda di
    // prova rifare le righe costava 10-32 ms, misurato). Qui si ricostruisce solo
    // la riga che cambia stato.
    return Selector<SelezioneDeiTodo, (bool, bool)>(
      selector: (_, selezione) => (
        selezione.attiva,
        selezione.contiene(entry.todo.id),
      ),
      builder: (context, stato, _) => stato.$1
          ? _inSelezione(context, scelto: stato.$2)
          : _normale(context),
    );
  }

  /// La riga normale: la scheda con i suoi due gesti.
  Widget _normale(BuildContext context) {
    final provider = context.read<TodoProvider>();
    final scheme = Theme.of(context).colorScheme;
    final todo = entry.todo;
    final next = entry.next;
    final rule = RecurrenceRule.tryParse(todo.recurrenceRule);

    void deleteWithUndo() {
      provider.deleteTodo(todo.id);
      showUndoSnackBar(
        context,
        message: 'To do eliminato',
        onUndo: () => provider.restoreTodo(todo),
      );
    }

    // Spuntare: per un ricorrente segna **quella** occorrenza (la serie resta),
    // per un todo singolo cambia lo stato del todo. Lo usano il cerchio e lo
    // scorrimento a destra, cosi' i due gesti fanno la stessa cosa.
    void toggle() {
      tickFeedback();
      provider.toggleForDay(todo, next ?? todo.dueDate ?? DateTime.now());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.xs,
        AppSpacing.m,
        AppSpacing.xs,
      ),
      child: Dismissible(
        key: ValueKey(todo.id),
        direction: DismissDirection.horizontal,
        // A destra si **spunta** (il gesto piu' frequente, come in Microsoft To
        // Do), a sinistra si cancella. Spuntare non toglie la riga: la sparizione
        // improvvisa non e' un'animazione, e' perdere il punto in cui eri.
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            toggle();
            return false;
          }
          return true;
        },
        onDismissed: (_) => deleteWithUndo(),
        background: Container(
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: AppSpacing.l),
          child: Icon(Icons.check, color: scheme.onTertiaryContainer),
        ),
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.l),
          child: Icon(Icons.delete, color: scheme.onErrorContainer),
        ),
        child: TodoCard(
          todo: todo,
          done: entry.done,
          dueOverride: entry.due,
          onToggle: toggle,
          onLongPress: () {
            tickFeedback();
            context.read<SelezioneDeiTodo>().apri(todo.id);
          },
          onTap: () => showItemDetail(
            context,
            todo: todo,
            day: todo.dueDate ?? DateTime.now(),
          ),
          recurrence: rule == null
              ? null
              : recurrenceLabel(
                  rule,
                  anchor: todo.dueDate ?? next ?? DateTime.now(),
                ),
        ),
      ),
    );
  }

  /// La riga mentre si sceglie: niente scorrimento, un tocco per entrare o
  /// uscire, e il fondo colorato quando e' dentro.
  Widget _inSelezione(BuildContext context, {required bool scelto}) {
    final todo = entry.todo;
    final rule = RecurrenceRule.tryParse(todo.recurrenceRule);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.xs,
        AppSpacing.m,
        AppSpacing.xs,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        // Il velo va in **primo piano**, non dietro: la scheda ha il suo fondo
        // opaco e un colore messo dietro non si vede. Preso sul telefono, non dai
        // test: le righe scelte sembravano identiche alle altre.
        foregroundDecoration: scelto
            ? BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: scheme.primary, width: 2),
              )
            : null,
        child: TodoCard(
          todo: todo,
          done: entry.done,
          dueOverride: entry.due,
          // Il cerchio fa la stessa cosa della riga: dentro o fuori. Cosi' chi
          // tocca li' non spunta per sbaglio mentre sta scegliendo.
          onToggle: () {
            tickFeedback();
            context.read<SelezioneDeiTodo>().inverti(todo.id);
          },
          onTap: () {
            tickFeedback();
            context.read<SelezioneDeiTodo>().inverti(todo.id);
          },
          recurrence: rule == null
              ? null
              : recurrenceLabel(rule, anchor: todo.dueDate ?? DateTime.now()),
        ),
      ),
    );
  }
}
