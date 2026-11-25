import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../theme/design_tokens.dart';

/// Il foglio «Crea» delle Note: una sola azione primaria (`+`) con due scelte.
///
/// Due `+` affiancati (nota e cartella) sembravano la stessa cosa: qui la nota
/// resta la scelta principale, la cartella è la seconda, e la barra delle
/// cartelle non ha più un pulsante suo.
Future<String?> mostraCreaSheet(BuildContext context) {
  return showActaSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
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
              child: Text('Crea', style: theme.textTheme.titleMedium),
            ),
            ListTile(
              key: const ValueKey('crea-nota'),
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('Nota'),
              subtitle: const Text('Testo, checklist, collegamenti'),
              onTap: () => Navigator.pop(ctx, 'nota'),
            ),
            ListTile(
              key: const ValueKey('crea-cartella'),
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Cartella'),
              subtitle: const Text('Raggruppa le note per argomento'),
              onTap: () => Navigator.pop(ctx, 'cartella'),
            ),
            const SizedBox(height: AppSpacing.s),
          ],
        ),
      );
    },
  );
}
