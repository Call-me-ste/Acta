import 'package:flutter/material.dart';

import '../../features/notes/note_blocks.dart';
import '../../theme/design_tokens.dart';
import 'note_text_style.dart';

/// Il testo della nota in modalità **Leggi**: paragrafi, puntati, numerati e
/// checkbox spuntabili. Nessun editor ricco: solo struttura.
class NoteBlocksView extends StatelessWidget {
  const NoteBlocksView({
    super.key,
    required this.blocks,
    required this.onToggle,
    this.attachmentBuilder,
  });

  final List<NoteBlock> blocks;
  final void Function(int line, bool checked) onToggle;
  final Widget Function(String id)? attachmentBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final blocco = blocks[index];
        return switch (blocco.kind) {
          NoteBlockKind.paragraph => _paragrafo(theme, blocco),
          NoteBlockKind.heading => _titolo(theme, blocco),
          NoteBlockKind.bullet => _punto(theme, blocco),
          NoteBlockKind.numbered => _numerato(theme, blocco),
          NoteBlockKind.checkbox => _check(theme, blocco),
          NoteBlockKind.attachment => attachmentBuilder?.call(blocco.text) ??
              const ListTile(title: Text('Allegato non disponibile')),
        };
      },
    );
  }

  EdgeInsets _rientro(NoteBlock blocco) =>
      EdgeInsets.only(left: blocco.indent * 16.0);

  Widget _titolo(ThemeData theme, NoteBlock blocco) {
    if (blocco.text.trim().isEmpty) {
      return const SizedBox(height: AppSpacing.s);
    }
    final stile = switch (blocco.level) {
      1 => theme.textTheme.headlineSmall,
      2 => theme.textTheme.titleLarge,
      _ => theme.textTheme.titleMedium,
    };
    return Padding(
      padding: _rientro(blocco).add(
        const EdgeInsets.symmetric(vertical: AppSpacing.s),
      ),
      child: Text(
        blocco.text,
        style: noteTextStyle(
            theme, stile?.copyWith(fontWeight: FontWeight.w600), blocco.format),
      ),
    );
  }

  Widget _paragrafo(ThemeData theme, NoteBlock blocco) {
    if (blocco.text.trim().isEmpty) {
      return const SizedBox(height: AppSpacing.s);
    }
    return Padding(
      padding: _rientro(blocco).add(
        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      ),
      child: Text(blocco.text,
          style:
              noteTextStyle(theme, theme.textTheme.bodyLarge, blocco.format)),
    );
  }

  Widget _punto(ThemeData theme, NoteBlock blocco) {
    return Padding(
      padding: _rientro(blocco).add(
        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '•',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Expanded(
            child: Text(blocco.text,
                style: noteTextStyle(
                    theme, theme.textTheme.bodyLarge, blocco.format)),
          ),
        ],
      ),
    );
  }

  Widget _numerato(ThemeData theme, NoteBlock blocco) {
    return Padding(
      padding: _rientro(blocco).add(
        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${blocco.number}.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Expanded(
            child: Text(blocco.text,
                style: noteTextStyle(
                    theme, theme.textTheme.bodyLarge, blocco.format)),
          ),
        ],
      ),
    );
  }

  Widget _check(ThemeData theme, NoteBlock blocco) {
    return Padding(
      padding: _rientro(blocco).add(
        const EdgeInsets.symmetric(vertical: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: ValueKey('check-nota-${blocco.line}'),
            value: blocco.checked,
            onChanged: (valore) => onToggle(blocco.line, valore ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                blocco.text,
                style: noteTextStyle(
                    theme,
                    theme.textTheme.bodyLarge?.copyWith(
                      decoration:
                          blocco.checked ? TextDecoration.lineThrough : null,
                      color: blocco.checked
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                    blocco.format),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
