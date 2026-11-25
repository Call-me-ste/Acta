import 'package:flutter/material.dart';

import '../../features/backup/backup_controller.dart';
import '../../features/backup/domain/backup_file.dart';
import '../../theme/design_tokens.dart';
import 'backup_extras.dart';
import 'backup_sections.dart';

/// Stato della copia automatica, esportazione e ripristino delle copie recenti.
class BackupPaginaSemplice extends StatelessWidget {
  const BackupPaginaSemplice({
    super.key,
    required this.copie,
    required this.onEsporta,
    required this.onImporta,
    required this.onRipristina,
    this.drive,
  });

  final BackupController copie;
  final VoidCallback onEsporta;
  final VoidCallback onImporta;
  final void Function(BackupFile copia) onRipristina;
  final Widget? drive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ultima = copie.ultimaCopia;
    final preAggiornamento = copie.copiaPreAggiornamento;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (copie.occupato) const LinearProgressIndicator(),
        Text('Copie sul telefono', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ultima == null
              ? 'Nessuna copia automatica ancora.'
              : 'L\'ultima è di ${quandoBreve(ultima)}.',
          key: const ValueKey('stato-copie'),
          style: theme.textTheme.bodyMedium,
        ),
        const Divider(height: AppSpacing.xl),
        ListTile(
          key: const ValueKey('esporta-copia'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.ios_share),
          title: const Text('Esporta una copia'),
          subtitle: const Text('Salvala fuori dal telefono'),
          onTap: copie.occupato ? null : onEsporta,
        ),
        ListTile(
          key: const ValueKey('importa-copia'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.file_open_outlined),
          title: const Text('Ripristina da un file'),
          onTap: copie.occupato ? null : onImporta,
        ),
        if (drive case final entry?) entry,
        const Divider(height: AppSpacing.xl),
        // Tre copie, non tutte: chi ripristina sta cercando l'ultima buona.
        BackupElencoCopie(
          copie: copie,
          onScegli: onRipristina,
          quante: 3,
          titolo: 'Ripristina una copia',
        ),
        if (preAggiornamento != null) ...[
          const SizedBox(height: AppSpacing.s),
          Text(
            'Copia prima dell\'ultimo aggiornamento: '
            '${quandoBreve(preAggiornamento.createdAt)}.',
            key: const ValueKey('copia-pre-aggiornamento'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Divider(height: AppSpacing.xl),
        const BackupPrimaDiDisinstallare(),
      ],
    );
  }
}
