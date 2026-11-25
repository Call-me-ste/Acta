import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../features/notes/domain/note_folder.dart';
import '../../features/notes/note_provider.dart';
import 'note_folder_dialog.dart';

/// Crea una cartella e la restituisce (null se annullato).
Future<NoteFolder?> creaCartella(
  BuildContext context,
  NoteProvider provider,
) async {
  final draft = await showNoteFolderDialog(context);
  if (draft == null) return null;
  return provider.addFolder(
    name: draft.name,
    colorIndex: draft.colorIndex,
  );
}

/// Sceglie una cartella. Ritorna `senza` per “Senza cartella”, l'id per una
/// cartella, `null` se si annulla.
Future<String?> scegliCartella(
  BuildContext context,
  NoteProvider provider,
) {
  return showActaSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: const Text('Senza cartella'),
            onTap: () => Navigator.pop(ctx, 'senza'),
          ),
          for (final folder in provider.folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder.name),
              onTap: () => Navigator.pop(ctx, folder.id),
            ),
        ],
      ),
    ),
  );
}

/// Rinomina/colore oppure elimina una cartella. L'eliminazione sposta le note
/// in “Senza cartella”, non le cancella.
Future<void> gestisciCartella(
  BuildContext context,
  NoteProvider provider,
  NoteFolder folder,
) async {
  final azione = await showActaSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('folder-pin'),
            leading: Icon(
              folder.pinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            title: Text(
              folder.pinned ? 'Togli dalla barra' : 'Fissa nella barra',
            ),
            onTap: () => Navigator.pop(ctx, 'pin'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rinomina e colore'),
            onTap: () => Navigator.pop(ctx, 'modifica'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Elimina cartella'),
            subtitle: const Text('Le note restano, vanno in Senza cartella'),
            onTap: () => Navigator.pop(ctx, 'elimina'),
          ),
        ],
      ),
    ),
  );
  if (azione == null || !context.mounted) return;

  if (azione == 'pin') {
    await provider.updateFolder(folder.copyWith(pinned: !folder.pinned));
    return;
  }

  if (azione == 'modifica') {
    final draft = await showNoteFolderDialog(context, folder: folder);
    if (draft == null) return;
    await provider.updateFolder(
      folder.copyWith(name: draft.name, colorIndex: draft.colorIndex),
    );
    return;
  }

  final conferma = await showActaDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Eliminare “${folder.name}”?'),
      content: const Text(
        'Le note non vengono cancellate: passeranno in “Senza cartella”.',
      ),
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
  if (conferma == true) {
    await provider.deleteFolder(folder);
  }
}
