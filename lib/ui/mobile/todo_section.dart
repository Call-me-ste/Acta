import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../shared/formatters.dart';
import '../shared/motion.dart';
import '../shared/picker_tile.dart';
import '../shared/priority_style.dart';
import '../shared/todo_time.dart';
import 'form_picker_sheet.dart';
import 'item_picking.dart';
import 'item_todo_part.dart';

/// La parte **todo** di un item: priorità, scadenza e orari.
///
/// I valori arrivano e tornano dentro un `ParteTodo` («La parte todo del form,
/// in un posto solo»): qui non si tiene stato, si sceglie e si riferisce. Con
/// **una** eccezione: l'apertura del selettore d'ora sta qui, perché i due orari
/// di un todo sono indipendenti — a differenza di quelli di un evento, che si
/// aggiustano a vicenda — e il form ha un tetto di righe da rispettare.
class TodoSection extends StatelessWidget {
  const TodoSection({
    super.key,
    required this.todo,
    required this.onTodo,
  });

  final ParteTodo todo;
  final ValueChanged<ParteTodo> onTodo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final riepilogo = todoTimeLabel(
      context,
      startMinutes: todo.startMinutes,
      endMinutes: todo.endMinutes,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerTile(
          icon: Icons.flag_outlined,
          label: 'Priorità',
          value: priorityLabel(todo.priority),
          leading: Icon(
            priorityIcon(todo.priority),
            size: AppSpacing.icon,
            color: priorityColor(context, todo.priority),
          ),
          onTap: () async {
            final scelta = await scegliPriorita(context, todo.priority);
            if (scelta != null && context.mounted) {
              onTodo(todo.copyWith(priority: scelta));
            }
          },
        ),
        PickerTile(
          icon: Icons.event_outlined,
          label: 'Scadenza',
          value: todo.dueDate == null ? 'Nessuna' : formatDay(todo.dueDate!),
          onTap: () => _scegliScadenza(context),
        ),
        // Gli orari compaiono **solo** con una scadenza: un'ora senza giorno non
        // vuol dire niente, ed è la stessa regola che `ParteTodo` fa rispettare.
        if (todo.dueDate != null)
          ListTileTheme.merge(
            minLeadingWidth: AppSpacing.icon,
            horizontalTitleGap: AppSpacing.m,
            child: ExpansionTile(
              expansionAnimationStyle: menuMotion(context),
              key: const ValueKey('orario-todo'),
              initiallyExpanded: todo.conOrario,
              title: Text(
                'Orario',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              subtitle: riepilogo == null ? null : Text(riepilogo),
              leading: Icon(
                Icons.schedule_outlined,
                size: AppSpacing.icon,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              minTileHeight: AppSpacing.touchTarget,
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              children: [
                PickerTile(
                  icon: Icons.schedule,
                  label: 'Inizio',
                  value: todo.startMinutes == null
                      ? 'Nessuno'
                      : oraBreve(context, todo.startMinutes!),
                  onTap: () => _scegliOrario(context, isStart: true),
                ),
                PickerTile(
                  icon: Icons.schedule_outlined,
                  label: 'Fine',
                  value: todo.endMinutes == null
                      ? 'Nessuno'
                      : oraBreve(context, todo.endMinutes!),
                  onTap: () => _scegliOrario(context, isStart: false),
                ),
              ],
            ),
          ),
        if (todo.dueDate != null || todo.conOrario)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              children: [
                if (todo.dueDate != null)
                  TextButton(
                    onPressed: () => onTodo(todo.conScadenza(null)),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, AppSpacing.touchTarget),
                    ),
                    child: const Text('Rimuovi scadenza'),
                  ),
                if (todo.conOrario)
                  TextButton(
                    key: const ValueKey('rimuovi-orario'),
                    onPressed: () => onTodo(todo.conOrari(null, null)),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, AppSpacing.touchTarget),
                    ),
                    child: const Text('Rimuovi orario'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _scegliScadenza(BuildContext context) async {
    final scelta = await askItemDueDate(context, todo.dueDate);
    if (scelta == null || !context.mounted) return;
    onTodo(todo.conScadenza(scelta));
  }

  /// Apre il selettore per un lato e riferisce **entrambi** gli orari: così il
  /// form non deve sapere quale dei due si sta cambiando.
  Future<void> _scegliOrario(BuildContext context,
      {required bool isStart}) async {
    final scelto = await askTodoTime(
      context,
      current: isStart ? todo.startMinutes : todo.endMinutes,
    );
    if (scelto == null || !context.mounted) return;
    onTodo(
      todo.conOrari(
        isStart ? scelto : todo.startMinutes,
        isStart ? todo.endMinutes : scelto,
      ),
    );
  }
}
