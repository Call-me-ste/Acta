import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/categories/category_controller.dart';
import '../../features/todos/todo_filter.dart';
import '../../features/todos/todo_filter_controller.dart';
import '../../theme/design_tokens.dart';
import '../shared/filter_pill.dart';
import '../shared/priority_style.dart';
import '../shared/top_inset.dart';

/// L'intestazione della scheda Todo: **che cosa** si sta guardando, quanti ce ne
/// sono, e i due comandi che servono.
///
/// Tre informazioni, tre forme diverse, in ordine di importanza: il **nome della
/// vista** (grande, ed e' anche il comando per cambiarla: un tocco), il
/// **numero** di quello che si vede (un numero vero, non una nota a pie' di
/// riga), e i **filtri** come pastiglie — la stessa forma dell'agenda, che e' la
/// stessa cosa.
class TodoHeader extends StatelessWidget {
  const TodoHeader({super.key, required this.count});

  /// Quanti elementi si stanno vedendo: un elenco senza numero non dice se il
  /// filtro sta nascondendo qualcosa.
  final int count;

  Future<void> _cambiaVista(BuildContext context) async {
    final controller = context.read<TodoFilterController>();
    final scelta = await showActaSheet<TodoRange>(
      context: context,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - topInset(context),
      ),
      builder: (_) => _ViewSheet(selected: controller.filter.range),
    );
    if (scelta != null) controller.setRange(scelta);
  }

  Future<void> _apriFiltri(BuildContext context) async {
    await showActaSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - topInset(context),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = context.watch<TodoFilterController>().filter;
    final scelte = filter.categoryIds.length + filter.priorities.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          // Il nome della vista **e'** il comando per cambiarla: un tocco, e
          // dice sempre dove sei. E' la cosa piu' importante della riga, e si
          // vede: corpo grande, testo pieno.
          Expanded(
            child: InkWell(
              key: const ValueKey('cambia-vista'),
              onTap: () => _cambiaVista(context),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        todoRangeLabels[filter.range]!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 22),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          // Quanti ne sto vedendo: un **numero**, alla stessa altezza della
          // vista. Dice anche se un filtro sta nascondendo qualcosa.
          Flexible(
            child: Text(
              '$count To do',
              key: const ValueKey('conteggio-todo'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          // I filtri: una pastiglia, la stessa lingua dell'agenda. Il numero
          // dentro dice quanti sono attivi — senza, ci si dimentica di averli
          // messi e l'elenco sembra sbagliato.
          FilterPill(
            key: const ValueKey('apri-filtri'),
            testo: scelte == 0 ? 'Filtri' : 'Filtri · $scelte',
            icona: Icons.tune,
            attiva: scelte > 0,
            onTap: () => _apriFiltri(context),
          ),
        ],
      ),
    );
  }
}

/// Il menu' delle viste: poche voci, con il numero di elementi che contiene
/// ognuna sarebbe rumore — si sceglie il punto di vista, non si confrontano.
class _ViewSheet extends StatelessWidget {
  const _ViewSheet({required this.selected});

  final TodoRange selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.read<TodoFilterController>();

    return SafeArea(
      // Scorrevole come il foglio dei filtri: quando il foglio si chiude, la
      // sua altezza si riduce, e una colonna fissa andrebbe in overflow proprio
      // durante l'animazione (visto dal test).
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                AppSpacing.s,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Guarda', style: theme.textTheme.titleMedium),
              ),
            ),
            for (final range in TodoRange.values)
              ListTile(
                key: ValueKey('vista-${range.name}'),
                leading: Icon(_icona(range)),
                title: Text(todoRangeLabels[range]!),
                trailing: range == selected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () {
                  controller.setRange(range);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: AppSpacing.s),
          ],
        ),
      ),
    );
  }

  static IconData _icona(TodoRange range) => switch (range) {
        TodoRange.tutte => Icons.list_alt,
        TodoRange.oggi => Icons.today,
        TodoRange.oggiEDomani => Icons.event,
        TodoRange.prossimi7 => Icons.date_range,
        TodoRange.senzaData => Icons.block,
      };
}

/// Il foglio dei filtri fini: categorie e priorita', piu' "Azzera".
class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<TodoFilterController>();
    final filter = controller.filter;
    final categories = context.watch<CategoryController>().all;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filtri', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.m),
            Text('Priorita\'', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.xs,
              children: [
                for (var livello = priorityLabels.length - 1;
                    livello >= 0;
                    livello--)
                  FilterChip(
                    key: ValueKey('filtro-priorita-$livello'),
                    label: Text(priorityLabel(livello)),
                    avatar: Icon(
                      priorityIcon(livello),
                      size: 16,
                      color: priorityColor(context, livello),
                    ),
                    selected: filter.priorities.contains(livello),
                    showCheckmark: false,
                    onSelected: (_) => controller.togglePriority(livello),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Text('Categorie', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            if (categories.isEmpty)
              Text(
                'Nessuna categoria: si creano da Impostazioni > Categorie.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final category in categories)
                    FilterChip(
                      key: ValueKey('filtro-categoria-${category.id}'),
                      label: Text(category.name),
                      selected: filter.categoryIds.contains(category.id),
                      showCheckmark: false,
                      onSelected: (_) => controller.toggleCategory(category.id),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.m),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('azzera-filtri'),
                onPressed: controller.isDefault ? null : controller.reset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Azzera i filtri'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
