import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../theme/design_tokens.dart';

/// La toolbar dell'editor: struttura della nota, in basso sopra la tastiera.
///
/// Non è un contenitore dentro il contenuto: sta **sotto** il testo, dove il
/// pollice arriva mentre si scrive, e si vede solo in scrittura.
class NoteEditorToolbar extends StatelessWidget {
  const NoteEditorToolbar({
    super.key,
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

  final VoidCallback onChecklist;
  final VoidCallback onBullet;
  final VoidCallback onNumbered;
  final VoidCallback onHeading;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;
  final int? listIndent;
  final ValueChanged<String> onFormat;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.large),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final indent = listIndent;
            final buttons =
                5 + (onAttach == null ? 0 : 1) + (indent == null ? 0 : 1);
            final fits = constraints.maxWidth >=
                buttons * AppSpacing.touchTarget + AppSpacing.xs;
            final children = <Widget>[
              IconButton(
                key: const ValueKey('nota-checklist'),
                tooltip: 'Checklist',
                onPressed: onChecklist,
                icon: const Icon(Icons.check_box_outlined),
              ),
              IconButton(
                key: const ValueKey('nota-puntato'),
                tooltip: 'Elenco puntato',
                onPressed: onBullet,
                icon: const Icon(Icons.format_list_bulleted),
              ),
              IconButton(
                key: const ValueKey('nota-numerato'),
                tooltip: 'Elenco numerato',
                onPressed: onNumbered,
                icon: const Icon(Icons.format_list_numbered),
              ),
              IconButton(
                key: const ValueKey('nota-titolo'),
                tooltip: 'Titolo',
                onPressed: onHeading,
                icon: const Icon(Icons.title),
              ),
              PopupMenuButton<String>(
                popUpAnimationStyle: menuMotion(context),
                key: const ValueKey('nota-formato-testo'),
                tooltip: 'Colore della riga',
                requestFocus: false,
                onSelected: onFormat,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'highlight',
                      child: Text('Attiva o togli evidenziazione')),
                  PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'default', child: Text('Colore predefinito')),
                  PopupMenuItem(value: 'blue', child: Text('Blu')),
                  PopupMenuItem(value: 'green', child: Text('Verde')),
                  PopupMenuItem(value: 'red', child: Text('Rosso')),
                  PopupMenuItem(value: 'purple', child: Text('Viola')),
                ],
                icon: const Icon(Icons.format_color_text),
              ),
              if (fits) const Spacer(),
              if (onAttach != null)
                IconButton(
                  key: const ValueKey('nota-allega'),
                  tooltip: 'Aggiungi allegato',
                  onPressed: onAttach,
                  icon: const Icon(Icons.attach_file),
                ),
              if (indent != null)
                PopupMenuButton<bool>(
                  popUpAnimationStyle: menuMotion(context),
                  key: const ValueKey('nota-rientro'),
                  tooltip: 'Rientro',
                  requestFocus: false,
                  onSelected: (destra) => destra ? onIndent() : onOutdent(),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      key: const ValueKey('nota-rientro-piu'),
                      value: true,
                      enabled: indent < 3,
                      child: const Text('Sposta a destra'),
                    ),
                    PopupMenuItem(
                      key: const ValueKey('nota-rientro-meno'),
                      value: false,
                      enabled: indent > 0,
                      child: const Text('Sposta a sinistra'),
                    ),
                  ],
                  icon: const Icon(Icons.format_indent_increase),
                ),
              const SizedBox(width: AppSpacing.xs),
            ];
            return fits ? Row(children: children) : Wrap(children: children);
          },
        ),
      ),
    );
  }
}
