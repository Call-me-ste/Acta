import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/events/event_provider.dart';
import '../../features/overdue/domain/overdue_item.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/todo_overdue.dart';
import '../../features/todos/todo_provider.dart';
import '../../theme/design_tokens.dart';
import '../shared/form_sheet.dart';
import '../shared/feedback.dart';
import '../shared/formatters.dart';

List<OverdueItem> scadutiDaConfermare(BuildContext context) {
  final giorni = context.read<AppSettingsController>().overdueWindowDays;
  final oggi = DateTime.now();
  return sortedOverdue(
    context.read<EventProvider>().overdue(giorni, until: oggi),
    context.read<TodoProvider>().overdue(giorni, until: oggi),
  );
}

/// Chiede conferma per gli elementi passati: «è stato fatto?».
///
/// «Fatto» scrive la conferma (per un evento e per un ricorrente una riga per
/// occorrenza, per un todo singolo `completed`); «No» non scrive **niente** —
/// è una risposta, non un rinvio: l'elemento ricompare alla prossima apertura.
Future<void> showOverdueSheet(BuildContext context, List<OverdueItem> items) {
  return showFormSheet(context, (_) => OverdueSheet(items: items));
}

class OverdueSheet extends StatefulWidget {
  const OverdueSheet({super.key, required this.items, this.maxVisible = 10});

  final List<OverdueItem> items;

  /// Oltre questa soglia si dice quanti ne restano: la richiesta è una
  /// conferma, non un secondo elenco di todo.
  final int maxVisible;

  @override
  State<OverdueSheet> createState() => _OverdueSheetState();
}

class _OverdueSheetState extends State<OverdueSheet> {
  late final List<OverdueItem> _items = [...widget.items];

  /// Rispondere — in un modo o nell'altro — toglie la riga dall'elenco: la
  /// richiesta è di quelle che si esauriscono, quindi quando non resta niente
  /// da confermare il foglio si chiude da solo (un foglio vuoto è un vicolo
  /// cieco).
  void _dismiss(OverdueItem item) {
    setState(() => _items.remove(item));
    if (_items.isEmpty && mounted) Navigator.pop(context);
  }

  void _confirm(OverdueItem item) {
    tickFeedback();
    if (item.isEvent) {
      context.read<EventProvider>().confirmOccurrence(item.id, item.date);
    } else {
      context.read<TodoProvider>().confirmOverdue(item.id, item.date);
    }
    _dismiss(item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _items.take(widget.maxVisible).toList();
    final hidden = _items.length - visible.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Il maniglione lo mette il tema dei fogli (showDragHandle): qui non
          // serve una seconda barretta identica.
          Text('Scaduti da confermare', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Segna cosa hai fatto: quello che lasci stare ricompare la prossima '
            'volta.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final item in visible)
                    _OverdueRow(
                      item: item,
                      onSkip: () => _dismiss(item),
                      onDone: () => _confirm(item),
                    ),
                  if (hidden > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'e altri $hidden',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverdueRow extends StatelessWidget {
  const _OverdueRow({
    required this.item,
    required this.onSkip,
    required this.onDone,
  });

  final OverdueItem item;
  final VoidCallback onSkip;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              formatShortDay(item.date),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Icon(
            item.isEvent ? Icons.event_outlined : Icons.checklist_outlined,
            semanticLabel: item.isEvent ? 'Evento' : 'To do',
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: onSkip,
            child: const Text('Non ora'),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(
            onPressed: onDone,
            child: const Text('Fatto'),
          ),
        ],
      ),
    );
  }
}
