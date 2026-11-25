import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'note_editor_menu.dart';

/// La barra dell'editor: indietro, «Salvato», annulla/ripristina, menu `⋮`.
///
/// Le spaziature sono le stesse di [PageHeader]: leading 48, titolo a 8 dal
/// leading, azioni a 8 dal bordo.
class NoteEditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NoteEditorAppBar({
    super.key,
    required this.salvato,
    this.saveFailed = false,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.pinned,
    required this.anteprima,
    required this.collegaDisponibile,
    required this.onSelected,
    required this.onBack,
  });

  final bool salvato;
  final bool saveFailed;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool pinned;
  final bool anteprima;
  final bool collegaDisponibile;
  final ValueChanged<String> onSelected;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      leadingWidth: AppSpacing.touchTarget,
      titleSpacing: AppSpacing.s,
      actionsPadding: const EdgeInsets.only(right: AppSpacing.s),
      leading: IconButton(
        key: const ValueKey('indietro-nota'),
        tooltip: 'Indietro',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      title: salvato || saveFailed
          ? Text(
              saveFailed ? 'Non salvato' : 'Salvato',
              style: theme.textTheme.labelMedium?.copyWith(
                color: saveFailed
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      actions: [
        IconButton(
          key: const ValueKey('nota-undo'),
          tooltip: 'Annulla',
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          key: const ValueKey('nota-redo'),
          tooltip: 'Ripristina',
          onPressed: canRedo ? onRedo : null,
          icon: const Icon(Icons.redo),
        ),
        NoteEditorMenu(
          pinned: pinned,
          anteprima: anteprima,
          collegaDisponibile: collegaDisponibile,
          onSelected: onSelected,
        ),
      ],
    );
  }
}
