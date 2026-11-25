import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/categories/category_controller.dart';
import '../../features/events/domain/event.dart';
import '../../features/notifications/notification_settings_controller.dart';
import '../../features/recurrence/domain/recurrence_label.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../features/todos/domain/todo.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/todos/todo_recurrence.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import '../shared/priority_style.dart';
import 'item_delete.dart';
import 'item_date_actions.dart';
import 'item_detail_row.dart';
import 'item_reminder_sheet.dart';
import 'item_sheet.dart';

/// La scheda di un evento o di un todo: si apre col tocco, **legge** e lascia
/// modificare con un pulsante esplicito.
///
/// Il long-press resta la selezione multipla: aprire il form direttamente era
/// un salto, e rendeva impossibile selezionare senza entrare nel form.
Future<void> showItemDetail(
  BuildContext context, {
  Event? event,
  Todo? todo,
  DateTime? day,
}) {
  return showActaSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (ctx) => _ItemDetail(
      event: event,
      todo: todo,
      day: day,
      parent: context,
    ),
  );
}

class _ItemDetail extends StatelessWidget {
  const _ItemDetail({
    required this.event,
    required this.todo,
    required this.day,
    required this.parent,
  });

  final Event? event;
  final Todo? todo;
  final DateTime? day;
  final BuildContext parent;

  bool get _isEvent => event != null;

  String get _title {
    final titolo = event?.title ?? todo?.title ?? '';
    return titolo.trim().isEmpty ? (_isEvent ? 'Evento' : 'To do') : titolo;
  }

  String get _quando {
    if (event != null) {
      final e = event!;
      final giorno = DateFormat('EEE d MMM y', 'it_IT').format(day ?? e.start);
      if (e.allDay) return '$giorno · tutto il giorno';
      final inizio = DateFormat('HH:mm', 'it_IT').format(e.start);
      final fine = DateFormat('HH:mm', 'it_IT').format(e.end);
      return '$giorno · $inizio–$fine';
    }
    final t = todo!;
    if (t.dueDate == null) return 'Nessuna scadenza';
    final giorno = DateFormat('EEE d MMM y', 'it_IT').format(day ?? t.dueDate!);
    if (t.startMinutes == null) return giorno;
    final inizio = _ora(t.startMinutes!);
    final fine = t.endMinutes == null ? '' : '–${_ora(t.endMinutes!)}';
    return '$giorno · $inizio$fine';
  }

  static String _ora(int minuti) {
    final h = (minuti ~/ 60).toString().padLeft(2, '0');
    final m = (minuti % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _promemoria(BuildContext context) {
    final leads = event?.reminderLeads ?? todo?.reminderLeads;
    if (leads == null) {
      final notifiche = context.read<NotificationSettingsController?>();
      final predefinito = _isEvent
          ? (notifiche?.anticipoEventi ?? 15)
          : (notifiche?.anticipoTodo ?? 0);
      return '${reminderSummary(null, predefinito)} (predefinito)';
    }
    if (leads.isEmpty) return 'Nessuno';
    return '${leads.map(leadPhrase).join(', ')} prima';
  }

  String? get _ricorrenza {
    final rule = RecurrenceRule.tryParse(
      event?.recurrenceRule ?? todo?.recurrenceRule ?? '',
    );
    if (rule == null) return null;
    final anchor = event?.start ?? todo?.dueDate ?? day ?? DateTime.now();
    final testo = recurrenceLabel(rule, anchor: anchor);
    return testo.isEmpty ? null : testo;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categorie = context.watch<CategoryController>();
    final ids = event?.categoryIds ?? todo?.categoryIds ?? const <String>[];
    final categoria = categorie.byIds(ids).firstOrNull;
    final colore = _isEvent
        ? ColorResolver.elementColor(
            brightness: theme.brightness,
            index: event!.colorIndex,
            customHex: event!.colorHex,
          )
        : (categoria == null
            ? scheme.primary
            : (ColorResolver.hexToColor(categoria.colorHex) ?? scheme.primary));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colore,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Text(
                  _isEvent ? 'Evento' : 'To do',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (todo != null)
                  Icon(
                    todo!.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: AppSpacing.iconSmall,
                    color: todo!.completed
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ItemDateActions(
                    parent: parent, event: event, todo: todo, day: day),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              _title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                decoration:
                    todo?.completed == true ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            ItemDetailRow(icona: Icons.schedule, testo: _quando),
            ItemDetailRow(
              icona: Icons.notifications_outlined,
              testo: 'Promemoria: ${_promemoria(context)}',
            ),
            if (_ricorrenza != null)
              ItemDetailRow(
                  icona: Icons.repeat, testo: 'Ripetizione: $_ricorrenza'),
            if (categoria != null)
              ItemDetailRow(
                icona: Icons.label_outline,
                testo: 'Categoria: ${categoria.name}',
              ),
            if (todo != null)
              ItemDetailRow(
                icona: priorityIcon(todo!.priority),
                testo: 'Priorità: ${priorityLabel(todo!.priority)}',
              ),
            if ((event?.location ?? todo?.location ?? '').isNotEmpty)
              ItemDetailRow(
                icona: Icons.place_outlined,
                testo: event?.location ?? todo!.location,
              ),
            if ((event?.note ?? todo?.note ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              Text('Note', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                event?.note ?? todo!.note,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.l),
            Row(
              children: [
                if (todo != null)
                  IconButton.filledTonal(
                    key: const ValueKey('dettaglio-spunta'),
                    tooltip: todo!.completed ? 'Riapri' : 'Segna fatto',
                    onPressed: () {
                      final provider = context.read<TodoProvider>();
                      provider.toggleForDay(
                        todo!,
                        todo!.dueDate ?? day ?? DateTime.now(),
                      );
                      Navigator.pop(parent);
                    },
                    icon: Icon(
                      todo!.completed ? Icons.undo : Icons.check,
                    ),
                  ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('dettaglio-modifica'),
                    onPressed: () {
                      Navigator.pop(context);
                      _apriForm(parent);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifica'),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                IconButton(
                  key: const ValueKey('dettaglio-elimina'),
                  tooltip: 'Elimina',
                  onPressed: () async {
                    final eliminato = await deleteItem(
                      parent,
                      what: _title,
                      event: event,
                      todo: todo,
                    );
                    if (eliminato && context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _apriForm(BuildContext context) {
    if (event != null) {
      showItemForm(
        context,
        type: ItemType.evento,
        day: event!.start,
        event: event,
      );
    } else {
      showItemForm(
        context,
        type: ItemType.todo,
        day: todo!.dueDate ?? day ?? DateTime.now(),
        todo: todo,
      );
    }
  }
}
