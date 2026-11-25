import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../features/notes/note_attachment_store.dart';
import '../../features/sync/sync_controller.dart';
import '../shared/opzioni_avanzate.dart';
import '../shared/motion.dart';
import 'note_attachment_recovery.dart';

part 'drive_backup_tile.dart';

/// Impostazioni di sincronizzazione.
///
/// Un solo gesto da imparare: collegare il proprio account Google. Da lì in poi
/// i dati seguono l'utente fra i suoi dispositivi — **sul suo** Drive, non su
/// quello di chi ha scritto l'app.
class SyncSettingsPage extends StatelessWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronizzazione')),
      body: Consumer<SyncController>(
        builder: (context, controller, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DriveCard(controller: controller),
            const SizedBox(height: 16),
            _Status(controller: controller),
            if (controller.canRecoverFromDrive && !controller.needsRecovery)
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('Controlla e recupera da Drive'),
                subtitle: const Text(
                    'Rileggi l’archivio e sincronizza le modifiche locali'),
                onTap: controller.isBusy ? null : controller.recoverFromDrive,
              ),
            if (context.read<NoteAttachmentStore?>() case final store?
                when controller.needsRecovery)
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Recupera su questo telefono'),
                subtitle: const Text('Verifica la chiave dell’archivio Drive'),
                onTap: () => recoverDriveArchive(context, store, controller),
              ),
            const SizedBox(height: 16),
            const _PrivacyNote(),
            if (controller.isSignedIn) ...[
              const SizedBox(height: 16),
              OpzioniAvanzate(
                key: const ValueKey('sync-opzioni-avanzate'),
                nota: 'Gestisci l’account collegato',
                children: [
                  if (controller.isSignedIn)
                    ListTile(
                      key: const ValueKey('sync-scollega'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Scollega account Google'),
                      onTap: controller.isBusy ? null : controller.signOut,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DriveCard extends StatelessWidget {
  const _DriveCard({required this.controller});

  final SyncController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_outlined),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('Google Drive',
                        style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              !controller.isSupported
                  ? 'La sincronizzazione non è ancora disponibile. I dati '
                      'restano su questo telefono.'
                  : controller.isSignedIn
                      ? 'Collegato al tuo account Google.'
                      : 'Collega il tuo account Google per tenere i dati '
                          'allineati fra i tuoi dispositivi.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (controller.isBusy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (!controller.isSupported) ...[
              // Il pulsante c'è ma è spento, con il motivo scritto: meglio di un
              // tasto che non fa niente.
              FilledButton.icon(
                key: const ValueKey('sync-collega'),
                onPressed: null,
                icon: const Icon(Icons.link_off),
                label: const Text('Non disponibile'),
              ),
            ] else if (controller.isSignedIn)
              FilledButton.icon(
                key: const ValueKey('sync-ora'),
                onPressed: controller.problem == SyncProblem.signIn
                    ? controller.connect
                    : controller.syncNow,
                icon: const Icon(Icons.sync),
                label: Text(switch (controller.problem) {
                  null => 'Sincronizza ora',
                  SyncProblem.signIn => 'Ricollega Google Drive',
                  _ => 'Riprova',
                }),
              )
            else
              FilledButton.icon(
                key: const ValueKey('sync-collega'),
                onPressed: controller.connect,
                icon: const Icon(Icons.login),
                label: const Text('Collega Google Drive'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.controller});

  final SyncController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = controller.account;
    final lastSync = controller.lastSyncTime;
    final error = controller.lastError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (account != null)
          Text('Account collegato: ${account.email}',
              style: theme.textTheme.bodyMedium),
        Text(
          lastSync == null
              ? 'Nessuna sincronizzazione ancora'
              : 'Ultima sincronizzazione: ${formatSyncTime(lastSync)}',
          style: theme.textTheme.bodySmall,
        ),
        if (controller.remoteShardCount case final count?)
          Text(
            count == 0
                ? 'Nessuna modifica disponibile su Drive'
                : 'Archivio disponibile su Drive',
            style: theme.textTheme.bodySmall,
          ),
        Text(
          controller.pendingCount == 0
              ? 'Nessuna modifica in attesa'
              : '${controller.pendingCount} modifiche in attesa',
          style: theme.textTheme.bodySmall,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              key: const ValueKey('sync-errore'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (controller.problem == SyncProblem.driveFull)
          TextButton(
              onPressed: () => _openStorage(context),
              child: const Text('Gestisci spazio')),
        if (controller.problem == SyncProblem.archiveMissing &&
            controller.createFreshArchive != null)
          TextButton(
              onPressed: () => _confirmRebuild(context),
              child: const Text('Crea un nuovo archivio')),
      ],
    );
  }

  Future<void> _confirmRebuild(BuildContext context) async {
    final confirmed = await showActaDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Creare un nuovo archivio Drive?'),
        content:
            const Text('Acta invierà i dati salvati su questo dispositivo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Crea archivio')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) await controller.rebuildArchive();
  }

  static Future<void> _openStorage(BuildContext context) async {
    try {
      await const MethodChannel('planner/backup')
          .invokeMethod<void>('gestisciSpazioDrive');
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Apri Google Drive e scegli Spazio di archiviazione.'),
        ));
      }
    }
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline,
            size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'I dati restano nello spazio privato del tuo Drive. Se scolleghi '
            'l\'account, restano sul telefono.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
