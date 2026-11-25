import 'package:flutter/material.dart';

import '../../features/notes/domain/note_folder.dart';
import '../../features/notes/note_blocks.dart';
import '../../theme/design_tokens.dart';
import 'note_block_editor.dart';
import 'note_blocks_view.dart';
import 'note_editor_meta.dart';

/// Il corpo dell'editor: titolo, meta e il testo a blocchi (o l'anteprima).
class NoteEditorBody extends StatelessWidget {
  const NoteEditorBody({
    super.key,
    required this.title,
    required this.content,
    required this.editorKey,
    required this.folders,
    required this.folderId,
    required this.updatedAt,
    required this.anteprima,
    required this.onFolder,
    required this.onContentChanged,
    required this.onToggle,
    required this.onHistory,
    required this.onListIndentChanged,
    this.attachmentBuilder,
  });

  final TextEditingController title;
  final String content;
  final GlobalKey<NoteBlockEditorState> editorKey;
  final List<NoteFolder> folders;
  final String? folderId;
  final DateTime? updatedAt;
  final bool anteprima;
  final VoidCallback onFolder;
  final ValueChanged<String> onContentChanged;
  final void Function(int line, bool checked) onToggle;
  final void Function(bool canUndo, bool canRedo) onHistory;
  final ValueChanged<int?> onListIndentChanged;
  final Widget Function(String id, VoidCallback? remove)? attachmentBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('note-title'),
          controller: title,
          textCapitalization: TextCapitalization.sentences,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            hintText: 'Titolo',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        NoteEditorMeta(
          folders: folders,
          folderId: folderId,
          updatedAt: updatedAt,
          onFolder: onFolder,
        ),
        const Divider(height: AppSpacing.s),
        Expanded(
          child: anteprima
              ? NoteBlocksView(
                  blocks: parseNoteBlocks(content),
                  onToggle: onToggle,
                  attachmentBuilder: (id) =>
                      attachmentBuilder?.call(id, null) ??
                      const ListTile(title: Text('Allegato non disponibile')),
                )
              : NoteBlockEditor(
                  key: editorKey,
                  initialText: content,
                  onChanged: onContentChanged,
                  onHistory: onHistory,
                  onListIndentChanged: onListIndentChanged,
                  attachmentBuilder: attachmentBuilder,
                ),
        ),
      ],
    );
  }
}
