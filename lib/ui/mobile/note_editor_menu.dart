import 'package:flutter/material.dart';
import '../shared/motion.dart';

/// Il menu `⋮` dell'editor: le azioni rare, fuori dal contenuto.
class NoteEditorMenu extends StatelessWidget {
  const NoteEditorMenu({
    super.key,
    required this.pinned,
    required this.anteprima,
    required this.collegaDisponibile,
    required this.onSelected,
  });

  final bool pinned;
  final bool anteprima;
  final bool collegaDisponibile;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      popUpAnimationStyle: menuMotion(context),
      key: const ValueKey('menu-nota'),
      tooltip: 'Azioni della nota',
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const ValueKey('nota-pin'),
          value: 'pin',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(pinned ? 'Rimuovi dalle fissate' : 'Fissa in cima'),
          ),
        ),
        PopupMenuItem(
          key: const ValueKey('nota-anteprima'),
          value: 'anteprima',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              anteprima ? Icons.edit_outlined : Icons.visibility_outlined,
            ),
            title: Text(anteprima ? 'Modifica nota' : 'Mostra anteprima'),
          ),
        ),
        if (collegaDisponibile)
          const PopupMenuItem(
            key: ValueKey('collega-nota'),
            value: 'collega',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.link),
              title: Text('Aggiungi collegamento'),
            ),
          ),
        const PopupMenuItem(
          key: ValueKey('nota-condividi'),
          value: 'condividi',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.share_outlined),
            title: Text('Condividi come testo'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          key: const ValueKey('nota-elimina'),
          value: 'elimina',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            iconColor: Theme.of(context).colorScheme.error,
            textColor: Theme.of(context).colorScheme.error,
            leading: const Icon(Icons.delete_outline),
            title: const Text('Elimina nota'),
          ),
        ),
      ],
    );
  }
}
