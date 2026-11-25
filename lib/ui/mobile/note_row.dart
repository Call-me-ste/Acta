import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/notes/domain/note.dart';
import '../../features/notes/domain/note_folder.dart';
import '../../features/notes/note_blocks.dart';
import '../../theme/design_tokens.dart';
import '../shared/confirm_delete.dart';

/// Una nota come **card di elenco**, nello stile Samsung Notes: titolo,
/// anteprima, cartella e data, con i gesti per fissare/eliminare.
///
/// La card è una superficie sola: non contiene altre card. La selezione cambia
/// il colore della superficie, non aggiunge un secondo contenitore.
class NoteRow extends StatelessWidget {
  const NoteRow({
    super.key,
    required this.note,
    required this.folder,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onPin,
    required this.onDelete,
    required this.onToggleSelected,
  });

  final Note note;
  final NoteFolder? folder;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final VoidCallback onToggleSelected;

  /// «oggi», «ieri», «12 ott», «12 ott 2025» se l'anno è un altro.
  static String when(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final oggi = DateTime(now.year, now.month, now.day);
    final giorno = DateTime(date.year, date.month, date.day);
    final differenza = oggi.difference(giorno).inDays;
    if (differenza == 0) return 'oggi';
    if (differenza == 1) return 'ieri';
    final formato = date.year == now.year ? 'd MMM' : 'd MMM y';
    return DateFormat(formato, 'it_IT').format(date);
  }

  /// L'anteprima è testo, non markdown: niente `- [x]`, `#` o `1.` nella lista.
  String _anteprima(List<NoteBlock> blocks) {
    return blocks
        .where((blocco) => blocco.kind != NoteBlockKind.attachment)
        .map((blocco) => blocco.text.trim())
        .where((testo) => testo.isNotEmpty && testo != '-' && testo != '•')
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quando = when(note.updatedAt);
    final blocks = parseNoteBlocks(note.content);
    final anteprima = _anteprima(blocks);
    final allegati =
        blocks.any((block) => block.kind == NoteBlockKind.attachment);
    final titolo = note.title.trim();
    final haTitolo = titolo.isNotEmpty;
    final sfondo = selected
        ? scheme.primaryContainer.withValues(alpha: 0.55)
        : scheme.surface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xs,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Dismissible(
          key: ValueKey('dismiss-${note.id}'),
          direction: DismissDirection.horizontal,
          background: _SfondoGesto(
            colore: scheme.primary,
            icona: note.pinned ? Icons.push_pin_outlined : Icons.push_pin,
            etichetta: note.pinned ? 'Togli' : 'Fissa',
            allineamento: Alignment.centerLeft,
          ),
          secondaryBackground: _SfondoGesto(
            colore: scheme.error,
            icona: Icons.delete_outline,
            etichetta: 'Elimina',
            allineamento: Alignment.centerRight,
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              onPin();
              return false;
            }
            return confirmDelete(context, 'la nota');
          },
          onDismissed: (_) => onDelete(),
          child: Material(
            color: sfondo,
            child: InkWell(
              key: ValueKey('nota-${note.id}'),
              onTap: onTap,
              onLongPress: onLongPress,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: AppSpacing.touchTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.s,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectionMode) ...[
                        Checkbox(
                          value: selected,
                          onChanged: (_) => onToggleSelected(),
                        ),
                        const SizedBox(width: AppSpacing.s),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              haTitolo
                                  ? titolo
                                  : (anteprima.isEmpty
                                      ? (allegati ? 'Allegati' : 'Bozza vuota')
                                      : anteprima),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (haTitolo && anteprima.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                anteprima,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (folder != null) ...[
                              const SizedBox(height: AppSpacing.s),
                              Text(
                                folder!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            quando,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (note.pinned) ...[
                            const SizedBox(height: AppSpacing.s),
                            Icon(
                              Icons.push_pin,
                              size: AppSpacing.iconSmall,
                              color: scheme.primary,
                            ),
                          ],
                          if (allegati) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Tooltip(
                              message: 'Contiene allegati',
                              child: Icon(
                                Icons.attach_file,
                                size: AppSpacing.iconSmall,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SfondoGesto extends StatelessWidget {
  const _SfondoGesto({
    required this.colore,
    required this.icona,
    required this.etichetta,
    required this.allineamento,
  });

  final Color colore;
  final IconData icona;
  final String etichetta;
  final Alignment allineamento;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: colore,
      alignment: allineamento,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icona,
              color: theme.colorScheme.onPrimary, size: AppSpacing.icon),
          const SizedBox(width: AppSpacing.s),
          Text(
            etichetta,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
