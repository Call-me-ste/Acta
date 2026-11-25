import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/sync/encrypted_sync_gateway.dart';
import '../../features/notes/note_attachment_store.dart';
import '../../features/sync/sync_controller.dart';
import '../../theme/design_tokens.dart';
import '../shared/motion.dart';
import 'recovery_input.dart';

export 'recovery_input.dart' show showRecoveryInput;

class SecurityRecoveryTile extends StatelessWidget {
  const SecurityRecoveryTile({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.read<NoteAttachmentStore?>();
    if (store == null) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.key_outlined),
      title: const Text('Sicurezza e recupero'),
      subtitle: const Text('Chiave di Acta e dati cifrati'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => _RecoveryPage(store: store)),
      ),
    );
  }
}

Future<bool> recoverDriveArchive(
  BuildContext context,
  NoteAttachmentStore store,
  SyncController sync,
) async {
  final account = sync.account;
  if (account == null) return false;
  final gateway = sync.createGateway();
  final accepted = await showRecoveryInput(
    context,
    title: 'Apri l’archivio su Drive',
    action: 'Verifica chiave',
    submit: (code) => store.useRecoveryCode(
      code,
      verify: (key) async {
        await EncryptedSyncGateway(gateway, key).verifyExistingArchiveKey();
        if (sync.account?.email != account.email) {
          throw StateError('L’account Google è cambiato. Riprova.');
        }
      },
    ),
  );
  if (accepted) await sync.syncNow();
  return accepted;
}

class _RecoveryPage extends StatefulWidget {
  const _RecoveryPage({required this.store});
  final NoteAttachmentStore store;

  @override
  State<_RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<_RecoveryPage> {
  late Future<bool?> _status = _readStatus();

  Future<bool?> _readStatus() async {
    try {
      return await widget.store.recoveryCopyConfirmed();
    } on StateError {
      return null;
    }
  }

  void _refresh() => setState(() => _status = _readStatus());

  Future<void> _saveCopy() async {
    final String code;
    try {
      code = await widget.store.recoveryCode();
    } catch (_) {
      if (mounted) _refresh();
      return;
    }
    if (!mounted) return;
    final copied = await showActaDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conserva la chiave di Acta'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Salvala in un gestore di password o in un posto sicuro, '
              'separato dal telefono. Chi la possiede può aprire i tuoi dati cifrati.',
            ),
            const SizedBox(height: AppSpacing.m),
            Text(code, style: const TextStyle(fontFamily: 'monospace')),
            TextButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copia chiave'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ho salvato la chiave'),
          ),
        ],
      ),
    );
    if (!mounted || copied != true) return;
    final confirmed = await showRecoveryInput(
      context,
      title: 'Verifica la copia salvata',
      action: 'Conferma copia',
      submit: widget.store.confirmRecoveryCopy,
    );
    if (confirmed && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController?>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sicurezza e recupero')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          const Text(
            'Google ti dà accesso a Drive. La chiave di Acta apre i dati '
            'sincronizzati, gli allegati e le copie cifrate esportate.',
          ),
          const SizedBox(height: AppSpacing.m),
          FutureBuilder<bool?>(
            future: _status,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return ListTile(
                  title: const Text('Impossibile leggere la chiave'),
                  subtitle: const Text('Tocca per riprovare'),
                  onTap: _refresh,
                );
              }
              final status = snapshot.data;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(status == true
                    ? Icons.verified_user_outlined
                    : Icons.key_outlined),
                title: Text(switch (status) {
                  true => 'Copia della chiave verificata',
                  false => 'Chiave da conservare',
                  null => 'Chiave assente su questo telefono',
                }),
                subtitle: Text(status == null
                    ? 'La chiave si crea con il primo backup cifrato, '
                        'allegato o nuovo archivio Drive.'
                    : 'Conserva la chiave in un posto sicuro'),
                onTap: status == null ? null : _saveCopy,
                trailing:
                    status == null ? null : const Icon(Icons.chevron_right),
              );
            },
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Recupera su questo telefono'),
            subtitle: Text(sync?.isSignedIn == true
                ? 'Verifica la chiave dell’archivio Google Drive'
                : 'Collega Google Drive oppure apri una copia da Dati e backup'),
            onTap: sync?.isSignedIn == true && sync?.isBusy == false
                ? () async {
                    if (await recoverDriveArchive(
                            context, widget.store, sync!) &&
                        mounted) {
                      _refresh();
                    }
                  }
                : null,
          ),
          const Text(
            'Se perdi sia il dispositivo che può aprire i dati sia la chiave, '
            'la copia cifrata non è recuperabile.',
          ),
        ],
      ),
    );
  }
}
