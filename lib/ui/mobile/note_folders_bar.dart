import 'package:flutter/material.dart';

import '../../features/notes/domain/note_folder.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import '../../theme/event_palette.dart';

/// La riga delle cartelle: **tab di testo**, non chip.
///
/// «Tutte», «Senza cartella», le cartelle e il «+». La selezione si legge dalla
/// sottolineatura e dal peso, come nelle app di note di sistema; le pillole
/// piene occupavano mezza schermata e sfondavano a destra.
class NoteFoldersBar extends StatelessWidget {
  const NoteFoldersBar({
    super.key,
    required this.folders,
    required this.selected,
    required this.onSelected,
    required this.onAll,
    required this.onLongPress,
  });

  final List<NoteFolder> folders;

  /// `tutte`, `senza` oppure l'id di una cartella.
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onAll;
  final ValueChanged<NoteFolder> onLongPress;

  @override
  Widget build(BuildContext context) {
    // Poche cartelle: si vedono tutte. Molte: solo quelle fissate, il resto nel
    // foglio «Tutte le cartelle». La selezione corrente resta visibile.
    final visibili = <NoteFolder>[
      if (folders.length <= 3)
        ...folders
      else
        ...folders.where((folder) => folder.pinned),
    ];
    if (selected != 'tutte' && selected != 'senza') {
      final corrente = folders.where((f) => f.id == selected).firstOrNull;
      if (corrente != null && !visibili.any((f) => f.id == corrente.id)) {
        visibili.add(corrente);
      }
    }

    return SizedBox(
      height: AppSpacing.labelBarHeight(context),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: AppSpacing.page),
              itemCount: visibili.length + 2,
              itemBuilder: (context, index) {
                if (index < 2) {
                  final id = index == 0 ? 'tutte' : 'senza';
                  return _Tab(
                    key: ValueKey('folder-chip-$id'),
                    label: index == 0 ? 'Tutte' : 'Senza cartella',
                    selected: selected == id,
                    onTap: () => onSelected(id),
                  );
                }
                final folder = visibili[index - 2];
                return GestureDetector(
                  onLongPress: () => onLongPress(folder),
                  child: _Tab(
                    key: ValueKey('folder-chip-${folder.id}'),
                    label: folder.name,
                    selected: selected == folder.id,
                    colore: ColorResolver.hexToColor(
                      EventPalette.at(folder.colorIndex),
                    ),
                    onTap: () => onSelected(folder.id),
                  ),
                );
              },
            ),
          ),
          IconButton(
            key: const ValueKey('folder-all'),
            tooltip: 'Tutte le cartelle',
            onPressed: onAll,
            icon: const Icon(Icons.folder_open_outlined, size: AppSpacing.icon),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.colore,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? colore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (colore != null) ...[
                Container(
                  width: AppSpacing.s,
                  height: AppSpacing.s,
                  decoration: BoxDecoration(
                    color: colore,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
