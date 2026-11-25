import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/notes/note_provider.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import '../../theme/event_palette.dart';
import 'note_folder_actions.dart';

/// Il foglio con **tutte** le cartelle: selezione, conteggio, pin, creazione.
///
/// La barra mostra solo le cartelle fissate (o tutte, se sono poche); qui c'è
/// l'elenco completo, senza far scorrere una fila di chip fuori schermo.
Future<String?> mostraCartelleSheet(
  BuildContext context, {
  required String selected,
}) {
  return showActaSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    builder: (ctx) => _CartelleSheet(selected: selected),
  );
}

class _CartelleSheet extends StatelessWidget {
  const _CartelleSheet({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<NoteProvider>();
    final folders = provider.folders;
    final counts = <String?, int>{};
    for (final note in provider.notes) {
      counts.update(note.folderId, (count) => count + 1, ifAbsent: () => 1);
    }

    Widget voce({
      required Key key,
      required Widget leading,
      required String titolo,
      String? nota,
      Widget? trailing,
      required String valore,
      VoidCallback? onLongPress,
    }) {
      final scelta = selected == valore;
      return ListTile(
        key: key,
        leading: leading,
        title: Text(titolo),
        subtitle: nota == null ? null : Text(nota),
        trailing: trailing ??
            (scelta
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : null),
        onTap: () => Navigator.pop(context, valore),
        onLongPress: onLongPress,
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: Text('Cartelle', style: theme.textTheme.titleMedium),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: (folders.isEmpty ? 1 : folders.length) + 5,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return voce(
                    key: const ValueKey('cartella-sheet-tutte'),
                    leading: const Icon(Icons.notes),
                    titolo: 'Tutte',
                    nota: '${provider.notes.length} note',
                    valore: 'tutte',
                  );
                }
                if (index == 1) {
                  return voce(
                    key: const ValueKey('cartella-sheet-senza'),
                    leading: const Icon(Icons.folder_off_outlined),
                    titolo: 'Senza cartella',
                    nota: '${counts[null] ?? 0} note',
                    valore: 'senza',
                  );
                }
                final count = folders.isEmpty ? 1 : folders.length;
                if (index == 2 || index == count + 3) {
                  return const Divider(height: AppSpacing.l);
                }
                if (index == count + 4) {
                  return ListTile(
                    key: const ValueKey('cartella-sheet-nuova'),
                    leading: const Icon(Icons.create_new_folder_outlined),
                    title: const Text('Nuova cartella'),
                    onTap: () => Navigator.pop(context, '__nuova__'),
                  );
                }
                if (folders.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.l),
                    child: Text('Nessuna cartella: crea la prima'),
                  );
                }
                final folder = folders[index - 3];
                return voce(
                  key: ValueKey('cartella-sheet-${folder.id}'),
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: ColorResolver.hexToColor(
                        EventPalette.at(folder.colorIndex),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  titolo: folder.name,
                  nota: '${counts[folder.id] ?? 0} note',
                  valore: folder.id,
                  trailing: IconButton(
                    key: ValueKey('pin-cartella-${folder.id}'),
                    tooltip: folder.pinned
                        ? 'Togli dalla barra'
                        : 'Fissa nella barra',
                    onPressed: () => provider
                        .updateFolder(folder.copyWith(pinned: !folder.pinned)),
                    icon: Icon(
                      folder.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: AppSpacing.iconSmall,
                    ),
                  ),
                  onLongPress: () =>
                      gestisciCartella(context, provider, folder),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
