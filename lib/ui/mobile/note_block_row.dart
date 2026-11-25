import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/notes/note_blocks.dart';
import '../../theme/design_tokens.dart';
import 'note_text_style.dart';

/// Una riga dell'editor a blocchi: segno (checkbox, punto, numero) e testo.
class NoteBlockRow extends StatelessWidget {
  const NoteBlockRow({
    super.key,
    required this.id,
    required this.kind,
    required this.indent,
    required this.controller,
    required this.focusNode,
    required this.checked,
    required this.number,
    required this.format,
    required this.hint,
    required this.onChanged,
    required this.onChecked,
    required this.onFocus,
    required this.onBackspaceAtStart,
  });

  final int id;
  final NoteBlockKind kind;
  final int indent;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool checked;
  final int? number;
  final NoteTextFormat format;
  final String? hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onChecked;
  final VoidCallback onFocus;
  final VoidCallback onBackspaceAtStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stile = kind == NoteBlockKind.heading
        ? theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)
        : theme.textTheme.bodyLarge?.copyWith(
            decoration: checked ? TextDecoration.lineThrough : null,
            color: checked ? scheme.onSurfaceVariant : null,
          );

    return Padding(
      padding: EdgeInsets.only(left: indent * 16.0, top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kind == NoteBlockKind.checkbox)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Checkbox(
                key: ValueKey('blocco-check-$id'),
                value: checked,
                onChanged: (valore) => onChecked(valore ?? false),
              ),
            )
          else if (kind == NoteBlockKind.bullet)
            _segno(theme, '•')
          else if (kind == NoteBlockKind.numbered)
            _segno(theme, '${number ?? 1}.'),
          Expanded(
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.backspace &&
                    controller.selection.isCollapsed &&
                    controller.selection.baseOffset == 0) {
                  onBackspaceAtStart();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                key: ValueKey('blocco-$id'),
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: noteTextStyle(theme, stile, format),
                onChanged: onChanged,
                onTap: onFocus,
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segno(ThemeData theme, String testo) {
    return SizedBox(
      width: 28,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          testo,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
