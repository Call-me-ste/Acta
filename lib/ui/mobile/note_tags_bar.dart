import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// La riga dei tag: i più usati, più il comando per l'elenco completo.
///
/// Come per le cartelle, la barra non diventa una fila infinita: mostra pochi
/// tag e lascia gli altri al foglio, che si apre dall'icona fissa a destra.
class NoteTagsBar extends StatelessWidget {
  const NoteTagsBar({
    super.key,
    required this.tags,
    required this.selected,
    required this.onSelected,
    required this.onAll,
  });

  final List<String> tags;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final visibili = tags.take(3).toList();
    if (selected != null && !visibili.contains(selected)) {
      visibili.add(selected!);
    }

    return SizedBox(
      height: AppSpacing.labelBarHeight(context),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: AppSpacing.page),
              itemCount: visibili.length,
              itemBuilder: (context, index) {
                final tag = visibili[index];
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: FilterChip(
                    key: ValueKey('tag-$tag'),
                    label: Text('#$tag'),
                    labelStyle: Theme.of(context).textTheme.labelLarge,
                    selected: selected == tag,
                    onSelected: (_) => onSelected(selected == tag ? null : tag),
                  ),
                );
              },
            ),
          ),
          IconButton(
            key: const ValueKey('tag-all'),
            tooltip: 'Tutti i tag',
            onPressed: onAll,
            icon: const Icon(Icons.sell_outlined, size: AppSpacing.icon),
          ),
        ],
      ),
    );
  }
}
