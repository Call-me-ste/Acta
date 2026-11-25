import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../features/notes/note_provider.dart';
import '../../theme/color_resolver.dart';
import '../../theme/event_palette.dart';

/// Picker cartella per l'editor. Ritorna `senza`, l'id o `null` se annulla.
Future<String?> scegliCartellaPerNota(
  BuildContext context,
  NoteProvider provider,
  String? corrente,
) {
  return showActaSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: provider.folders.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Senza cartella'),
              trailing: corrente == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, 'senza'),
            );
          }
          final folder = provider.folders[index - 1];
          return ListTile(
            leading: Icon(
              Icons.folder_outlined,
              color: ColorResolver.hexToColor(
                EventPalette.at(folder.colorIndex),
              ),
            ),
            title: Text(folder.name),
            trailing: corrente == folder.id ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, folder.id),
          );
        },
      ),
    ),
  );
}
