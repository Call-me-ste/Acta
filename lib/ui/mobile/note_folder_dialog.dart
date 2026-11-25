import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../features/notes/domain/note_folder.dart';
import '../../theme/color_resolver.dart';
import '../../theme/event_palette.dart';

class NoteFolderDraft {
  const NoteFolderDraft({required this.name, required this.colorIndex});

  final String name;
  final int colorIndex;
}

/// Nome e colore di una cartella. Ritorna `null` se si annulla.
Future<NoteFolderDraft?> showNoteFolderDialog(
  BuildContext context, {
  NoteFolder? folder,
}) {
  final nome = TextEditingController(text: folder?.name ?? '');
  var colore = folder?.colorIndex ?? 0;

  return showActaDialog<NoteFolderDraft>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(folder == null ? 'Nuova cartella' : 'Modifica cartella'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nome,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < EventPalette.length; i++)
                    _Pallino(
                      colore: ColorResolver.hexToColor(EventPalette.at(i)) ??
                          Colors.grey,
                      scelto: colore == i,
                      onTap: () => setState(() => colore = i),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final testo = nome.text.trim();
              if (testo.isEmpty) return;
              Navigator.pop(
                ctx,
                NoteFolderDraft(name: testo, colorIndex: colore),
              );
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    ),
  );
}

class _Pallino extends StatelessWidget {
  const _Pallino({
    required this.colore,
    required this.scelto,
    required this.onTap,
  });

  final Color colore;
  final bool scelto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: colore,
          shape: BoxShape.circle,
          border: Border.all(
            color: scelto
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: scelto
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}
