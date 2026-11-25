import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../features/backup/backup_attachment_files.dart';
import '../../features/backup/backup_controller.dart';
import '../../features/notes/note_attachment_store.dart';
import '../../features/updates/github_update.dart';
import '../../features/updates/update_controller.dart';

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, required this.controller});

  final UpdateController controller;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.check());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.check());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final update = widget.controller.visible;
        if (update == null) return const SizedBox.shrink();
        return SafeArea(
          bottom: false,
          child: Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: UpdateInstallTile(
              key: ValueKey(update.build),
              update: update,
              onDismiss: widget.controller.dismiss,
            ),
          ),
        );
      },
    );
  }
}

class UpdateInstallTile extends StatefulWidget {
  const UpdateInstallTile({super.key, required this.update, this.onDismiss});

  final GitHubUpdate update;
  final VoidCallback? onDismiss;

  @override
  State<UpdateInstallTile> createState() => _UpdateInstallTileState();
}

class _UpdateInstallTileState extends State<UpdateInstallTile> {
  bool _preparing = false;

  Future<void> _prepare() async {
    if (_preparing) return;
    final update = widget.update;
    final backup = context.read<BackupController>();
    final attachments = context.read<NoteAttachmentStore>();
    final messenger = ScaffoldMessenger.of(context);
    if (backup.occupato) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Attendi la fine della copia in corso.')));
      return;
    }
    setState(() => _preparing = true);
    String? error;
    var copyVerified = false;
    try {
      await backup.primaDiAggiornare();
      final copy = backup.copiaPreAggiornamento;
      if (backup.errore != null || copy == null) {
        error = backup.errore ?? 'La copia di sicurezza non è disponibile.';
      } else {
        final folder = backup.percorsoCartella;
        final pool = Directory(p.join(folder, 'note-attachments'));
        await BackupAttachmentFiles.verifyInPool(
          pool,
          File(p.join(folder, copy.name)),
          attachments.existingArchiveKey,
        );
        copyVerified = true;
        if (!mounted) return;
        if (await UpdateController.channel
                .invokeMethod<bool>('openRelease', update.tag) !=
            true) {
          error = 'Impossibile aprire GitHub. La copia di sicurezza è pronta.';
        }
      }
    } catch (_) {
      error = copyVerified
          ? 'Impossibile aprire GitHub. La copia di sicurezza è pronta.'
          : 'Impossibile verificare la copia completa. Controlla gli allegati e riprova.';
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
    if (mounted && error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: widget.onDismiss == null ? EdgeInsets.zero : null,
        leading: const Icon(Icons.system_update_alt),
        title: const Text('Aggiornamento disponibile'),
        subtitle: Text(_preparing
            ? 'Verifica della copia di sicurezza…'
            : 'Acta ${widget.update.version} (build ${widget.update.build})'
                '\nPrepara aggiornamento'),
        trailing: widget.onDismiss == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: 'Nascondi per ora',
                onPressed: _preparing ? null : widget.onDismiss,
                icon: const Icon(Icons.close),
              ),
        onTap: _preparing ? null : _prepare,
      );
}
