import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/notes/note_provider.dart';
import '../../features/notes/note_selection.dart';
import '../../theme/design_tokens.dart';
import 'note_folder_actions.dart';

/// La barra della selezione multipla delle note: conteggio, seleziona tutte,
/// pin, sposta in cartella, elimina. Le azioni sono compatte per stare in una
/// riga anche a testo grande.
class NoteSelectionBar extends StatelessWidget {
  const NoteSelectionBar({super.key, required this.visibili});

  final List<String> visibili;

  @override
  Widget build(BuildContext context) {
    final selezione = context.watch<SelezioneDelleNote>();
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('note-chiudi-selezione'),
              tooltip: 'Chiudi la selezione',
              icon: Icon(Icons.close, color: scheme.onPrimaryContainer),
              onPressed: selezione.chiudi,
            ),
            Flexible(
              child: Text(
                '${selezione.quanti} selezionate',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ),
            _azione(
              context,
              key: 'note-seleziona-tutte',
              tooltip: 'Seleziona tutte',
              icon: Icons.select_all,
              onPressed: () => selezione.tutti(visibili),
            ),
            _azione(
              context,
              key: 'note-pin-selezione',
              tooltip: 'Fissa / togli il pin',
              icon: Icons.push_pin_outlined,
              onPressed: () => _pin(context, selezione),
            ),
            _azione(
              context,
              key: 'note-sposta-selezione',
              tooltip: 'Sposta in cartella',
              icon: Icons.drive_file_move_outline,
              onPressed: () => _sposta(context, selezione),
            ),
            _azione(
              context,
              key: 'note-elimina-selezione',
              tooltip: 'Elimina',
              icon: Icons.delete_outline,
              onPressed: () => _elimina(context, selezione),
            ),
          ],
        ),
      ),
    );
  }

  Widget _azione(
    BuildContext context, {
    required String key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      key: ValueKey(key),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 22,
      icon: Icon(icon, color: scheme.onPrimaryContainer),
      onPressed: onPressed,
    );
  }

  Future<void> _pin(
    BuildContext context,
    SelezioneDelleNote selezione,
  ) async {
    final provider = context.read<NoteProvider>();
    final ids = selezione.ids;
    final tutteFissate = ids.every(
      (id) => provider.byId(id)?.pinned ?? false,
    );
    await provider.setPinnedMany(ids, !tutteFissate);
    if (context.mounted) selezione.chiudi();
  }

  Future<void> _sposta(
    BuildContext context,
    SelezioneDelleNote selezione,
  ) async {
    final provider = context.read<NoteProvider>();
    final scelta = await scegliCartella(context, provider);
    if (scelta == null || !context.mounted) return;
    final ids = selezione.ids;
    for (final id in ids) {
      final nota = provider.byId(id);
      if (nota != null) {
        await provider.moveNote(nota, scelta == 'senza' ? null : scelta);
      }
    }
    if (context.mounted) selezione.chiudi();
  }

  Future<void> _elimina(
    BuildContext context,
    SelezioneDelleNote selezione,
  ) async {
    final provider = context.read<NoteProvider>();
    final quanti = selezione.quanti;
    final conferma = await showActaDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminare $quanti note?'),
        content: const Text('L’operazione non si può annullare.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true || !context.mounted) return;
    final ids = selezione.ids;
    for (final id in ids) {
      await provider.deleteNote(id);
    }
    if (!context.mounted) return;
    selezione.chiudi();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$quanti note eliminate')),
    );
  }
}
