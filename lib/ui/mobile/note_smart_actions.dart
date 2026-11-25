import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../features/notes/note_smart_links.dart';
import '../../theme/design_tokens.dart';
import 'item_sheet.dart';

/// Le azioni “smart” di una nota: data → crea evento, URL/telefono → copia.
///
/// Massimo due chip, solo se c'è qualcosa di riconosciuto. Niente pannelli e
/// niente testo introduttivo: le azioni stanno sotto la nota e si vedono solo
/// quando servono.
class NoteSmartActions extends StatelessWidget {
  const NoteSmartActions({
    super.key,
    required this.titolo,
    required this.testo,
  });

  final String titolo;
  final String testo;

  void _copia(BuildContext context, String valore, String messaggio) {
    Clipboard.setData(ClipboardData(text: valore));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messaggio), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final links = estraiSmartLinks(testo);
    if (links.isEmpty) return const SizedBox.shrink();

    final data = links.where((l) => l.kind == SmartLinkKind.date).firstOrNull;
    final altro = links.where((l) => l.kind != SmartLinkKind.date).firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          if (data?.date != null)
            ActionChip(
              key: const ValueKey('smart-crea-evento'),
              avatar:
                  const Icon(Icons.event_available, size: AppSpacing.iconSmall),
              label: Text(
                'Crea evento ${DateFormat('d MMM', 'it_IT').format(data!.date!)}',
              ),
              onPressed: () => showItemForm(
                context,
                type: ItemType.evento,
                day: data.date!,
                initialTitle: titolo.trim().isEmpty ? null : titolo,
                initialNote: testo,
              ),
            ),
          if (altro != null)
            ActionChip(
              key: const ValueKey('smart-copia'),
              avatar: Icon(
                altro.kind == SmartLinkKind.url ? Icons.link : Icons.phone,
                size: AppSpacing.iconSmall,
              ),
              label: Text(
                altro.kind == SmartLinkKind.url ? 'Copia link' : 'Copia numero',
              ),
              onPressed: () => _copia(
                context,
                altro.text,
                altro.kind == SmartLinkKind.url
                    ? 'Link copiato'
                    : 'Numero copiato',
              ),
            ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
