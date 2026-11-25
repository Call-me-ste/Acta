import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/events/domain/event_occurrence.dart';
import '../../features/events/event_provider.dart';
import '../../features/todos/domain/todo.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/todos/todo_recurrence.dart';
import '../../theme/design_tokens.dart';
import '../shared/date_math.dart';
import '../shared/feedback.dart';
import '../shared/formatters.dart';
import '../shared/undo.dart';
import 'agenda_event_box.dart';
import 'item_detail_sheet.dart';
import 'todo_compact_row.dart';

/// Un giorno dell'agenda: intestazione a sinistra (**numero grande** e giorno
/// della settimana, con la linea che scende per tutto il gruppo) e, a destra,
/// quello che succede quel giorno — prima gli eventi di **giornata intera**, poi
/// quelli con l'orario, poi i todo.
///
/// La linea non è decorazione: tiene insieme a colpo d'occhio l'intestazione e le
/// righe, che sono due colonne diverse.
///
/// I gesti stanno **dentro**, come in `TodoTile`: il tocco apre il form, lo
/// scorrimento a sinistra elimina con l'annulla. L'annulla è la rete contro il
/// tocco sbagliato: un dialogo di conferma fermerebbe **tutti** i casi, anche
/// quelli in cui l'utente sa cosa sta facendo.
class AgendaDayGroup extends StatelessWidget {
  const AgendaDayGroup({
    super.key,
    required this.day,
    required this.allDay,
    required this.timed,
    required this.todos,
    this.oggi,
    this.showHeader = true,
    this.hasContinuation = false,
  });

  final DateTime day;

  /// Gli eventi di giornata intera: stanno **in cima** al gruppo.
  final List<EventOccurrence> allDay;

  /// Gli eventi con un orario, già in ordine.
  final List<EventOccurrence> timed;

  /// I todo del giorno. Vuoto quando la modalità dei todo li nasconde: la
  /// decisione è della pagina, che è quella che legge la preferenza.
  final List<Todo> todos;

  /// Oggi, per il numero colorato. `null` nei test: che giorno sia oggi non è
  /// una cosa da verificare.
  final DateTime? oggi;
  final bool showHeader;
  final bool hasContinuation;

  /// Quanto sta larga la colonna del giorno. **Fissa**, così le intestazioni di
  /// tutti i gruppi sono allineate sulla stessa verticale: è quello che rende
  /// leggibile la linea.
  static const double larghezzaGiorno = 46;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const lineWidth = 2.0;

    // La riga determina l'altezza una volta sola. Il fondino della data
    // nasconde il primo tratto della linea, a qualsiasi scala del testo.
    return Stack(
      children: [
        PositionedDirectional(
          start: (larghezzaGiorno - lineWidth) / 2,
          top: 0,
          bottom: 0,
          child: Container(
            width: lineWidth,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.vertical(
                top: showHeader
                    ? const Radius.circular(AppRadius.bar)
                    : Radius.zero,
                bottom: hasContinuation
                    ? Radius.zero
                    : const Radius.circular(AppRadius.bar),
              ),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: larghezzaGiorno,
              child: showHeader
                  ? ColoredBox(
                      key: const ValueKey('agenda-day-header'),
                      color: theme.scaffoldBackgroundColor,
                      child: _intestazione(theme, theme.colorScheme),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.xs,
                children: [
                  for (final occurrence in allDay)
                    _rigaEvento(context, occurrence),
                  for (final occurrence in timed)
                    _rigaEvento(context, occurrence),
                  for (final todo in todos) _rigaTodo(context, todo),
                  if (hasContinuation) const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _intestazione(ThemeData theme, ColorScheme scheme) {
    final adesso = oggi;
    final isOggi = adesso != null && dateOnly(adesso) == dateOnly(day);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Il numero si **adatta** invece di andare a capo: due cifre a corpo
        // grande, col testo ingrandito di sistema (sul telefono è a ~1,3), in 46
        // px non ci starebbero su una riga sola.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${day.day}',
            maxLines: 1,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: isOggi ? scheme.primary : scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          giornoBreve(day.weekday),
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }

  Widget _rigaEvento(BuildContext context, EventOccurrence occurrence) =>
      Dismissible(
        // La chiave porta anche il **giorno**: un ricorrente compare in piu'
        // gruppi, e due righe con la stessa chiave sono un errore.
        key: ValueKey('evento-${occurrence.event.id}-${day.toIso8601String()}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _eliminaEvento(context, occurrence),
        background: const _SfondoElimina(),
        child: AgendaEventBox(
          occurrence: occurrence,
          onTap: () => showItemDetail(
            context,
            event: occurrence.event,
            day: occurrence.date,
          ),
          onLongPress: () => _eliminaEvento(context, occurrence),
        ),
      );

  Widget _rigaTodo(BuildContext context, Todo todo) => Dismissible(
        key: ValueKey('todo-${todo.id}-${day.toIso8601String()}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _eliminaTodo(context, todo),
        background: const _SfondoElimina(),
        // Il tocco apre il form; quello del cerchio resta suo (spunta), perché
        // `TodoCompactRow` lo gestisce e questo sta **sotto** — lo stesso
        // schema della scheda Todo.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showItemDetail(
            context,
            todo: todo,
            day: todo.dueDate ?? day,
          ),
          child: TodoCompactRow(
            todo: todo,
            // Fatto: nella scheda del giorno si vede barrato, come in calendario.
            // L'agenda **non** ha lo scorrimento «fuori dal calendario»: li' il
            // gesto a sinistra cancella, ed e' quello che fa gia'.
            done: context.read<TodoProvider>().isDoneOn(todo, day),
            onToggle: () {
              tickFeedback();
              context.read<TodoProvider>().toggleForDay(todo, day);
            },
          ),
        ),
      );

  void _eliminaEvento(BuildContext context, EventOccurrence occurrence) {
    final eventi = context.read<EventProvider>();
    eventi.deleteEvent(occurrence.event.id);
    showUndoSnackBar(
      context,
      message: 'Evento eliminato',
      onUndo: () => eventi.restoreEvent(occurrence.event),
    );
  }

  void _eliminaTodo(BuildContext context, Todo todo) {
    final todos = context.read<TodoProvider>();
    todos.deleteTodo(todo.id);
    showUndoSnackBar(
      context,
      message: 'To do eliminato',
      onUndo: () => todos.restoreTodo(todo),
    );
  }
}

/// Il fondo rosso che si scopre tirando una riga verso sinistra.
class _SfondoElimina extends StatelessWidget {
  const _SfondoElimina();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.l),
      child: Icon(Icons.delete, color: scheme.onErrorContainer),
    );
  }
}
