import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/events/event_provider.dart';
import '../../features/todos/todo_provider.dart';
import 'note_editor_toolbar.dart';
import 'note_links_section.dart';
import 'note_smart_actions.dart';

/// Il piede dell'editor: azioni contestuali, collegamenti e toolbar.
///
/// Sta sotto il testo, non sopra: la toolbar è dove arriva il pollice mentre si
/// scrive, e le azioni smart compaiono solo quando c'è qualcosa da fare.
class NoteEditorFooter extends StatelessWidget {
  const NoteEditorFooter({
    super.key,
    required this.testo,
    required this.titolo,
    required this.contenuto,
    required this.noteId,
    required this.eventi,
    required this.todos,
    required this.anteprima,
    required this.onAnteprima,
    required this.onChecklist,
    required this.onBullet,
    required this.onNumbered,
    required this.onHeading,
    required this.onIndent,
    required this.onOutdent,
    required this.listIndent,
    required this.onFormat,
    this.onAttach,
  });

  final Listenable testo;
  final TextEditingController titolo;
  final ValueListenable<String> contenuto;
  final String noteId;
  final EventProvider? eventi;
  final TodoProvider? todos;
  final bool anteprima;
  final VoidCallback onAnteprima;
  final VoidCallback onChecklist;
  final VoidCallback onBullet;
  final VoidCallback onNumbered;
  final VoidCallback onHeading;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;
  final ValueListenable<int?> listIndent;
  final ValueChanged<String> onFormat;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: testo,
          builder: (context, _) => NoteSmartActions(
            titolo: titolo.text,
            testo: '${titolo.text}\n${contenuto.value}',
          ),
        ),
        NoteLinksSection(noteId: noteId, eventi: eventi, todos: todos),
        if (anteprima)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('nota-scrivi'),
              onPressed: onAnteprima,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifica nota'),
            ),
          )
        else
          ValueListenableBuilder<int?>(
            valueListenable: listIndent,
            builder: (context, indent, _) => NoteEditorToolbar(
              onChecklist: onChecklist,
              onBullet: onBullet,
              onNumbered: onNumbered,
              onHeading: onHeading,
              onIndent: onIndent,
              onOutdent: onOutdent,
              listIndent: indent,
              onFormat: onFormat,
              onAttach: onAttach,
            ),
          ),
      ],
    );
  }
}
