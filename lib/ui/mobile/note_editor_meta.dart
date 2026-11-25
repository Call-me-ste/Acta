import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/notes/domain/note_folder.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import '../../theme/event_palette.dart';

/// La riga di metadati dell'editor: cartella e ultimo aggiornamento.
///
/// Due elementi, non un pannello: la cartella è toccabile (apre il picker), la
/// data si legge e basta.
class NoteEditorMeta extends StatelessWidget {
  const NoteEditorMeta({
    super.key,
    required this.folders,
    required this.folderId,
    required this.updatedAt,
    required this.onFolder,
  });

  final List<NoteFolder> folders;
  final String? folderId;
  final DateTime? updatedAt;
  final VoidCallback onFolder;

  NoteFolder? get _folder {
    for (final folder in folders) {
      if (folder.id == folderId) return folder;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final folder = _folder;
    return Row(
      children: [
        Flexible(
          child: TextButton.icon(
            key: const ValueKey('cartella-nota'),
            onPressed: onFolder,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              visualDensity: VisualDensity.compact,
              foregroundColor: scheme.onSurfaceVariant,
              textStyle: theme.textTheme.labelMedium,
            ),
            icon: Icon(
              folder == null ? Icons.folder_off_outlined : Icons.folder,
              size: 16,
              color: folder == null
                  ? scheme.onSurfaceVariant
                  : ColorResolver.hexToColor(
                      EventPalette.at(folder.colorIndex),
                    ),
            ),
            label: Text(
              folder?.name ?? 'Senza cartella',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (updatedAt != null) ...[
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              DateFormat('d MMM y, HH:mm', 'it_IT').format(updatedAt!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
