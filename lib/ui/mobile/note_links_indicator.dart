import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../features/notes/domain/note.dart';
import '../../features/notes/note_provider.dart';
import '../../theme/design_tokens.dart';
import 'note_editor_page.dart';

/// Quante note sono collegate a un evento/todo, **solo nel suo dettaglio**.
///
/// Nel mese e nelle liste non compare niente: l'indicatore vive nel form di
/// modifica, dove l'utente sta già guardando quell'elemento.
class NoteLinksIndicator extends StatelessWidget {
  const NoteLinksIndicator({
    super.key,
    required this.noteProvider,
    required this.entityType,
    required this.entityId,
  });

  final NoteProvider noteProvider;

  /// `event` oppure `todo`.
  final String entityType;
  final String entityId;

  Future<void> _apri(BuildContext context) async {
    final note = [
      for (final link in noteProvider.linksOfEntity(entityType, entityId))
        if (noteProvider.byId(link.noteId) != null)
          noteProvider.byId(link.noteId)!,
    ];
    final scelta = await showActaDialog<Note>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Note collegate'),
        children: [
          for (final n in note)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n),
              child: Row(
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: AppSpacing.iconSmall),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      n.title.trim().isEmpty ? 'Senza titolo' : n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (scelta == null || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorPage(note: scelta),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: noteProvider,
      builder: (context, _) {
        final quante = noteProvider.linksOfEntity(entityType, entityId).length;
        if (quante == 0) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('note-collegate'),
            onPressed: () => _apri(context),
            icon: const Icon(
              Icons.sticky_note_2_outlined,
              size: AppSpacing.iconSmall,
            ),
            label: Text('Note collegate ($quante)'),
          ),
        );
      },
    );
  }
}
