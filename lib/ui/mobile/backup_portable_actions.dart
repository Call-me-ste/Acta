part of 'backup_page.dart';

extension _BackupPortableActions on BackupPage {
  Directory _pool(BackupController backups) =>
      Directory(p.join(backups.percorsoCartella, 'note-attachments'));

  Future<void> _condividiCifrata(
    BuildContext context,
    NoteAttachmentStore store,
    BackupController backups,
    File database,
  ) async {
    final stage =
        await (await getTemporaryDirectory()).createTemp('planner-backup-');
    try {
      final file = await const PortableEncryptedBackup().write(
        database: database,
        blobPool: _pool(backups),
        staging: stage,
        key: await store.archiveKey(),
      );
      if (context.mounted) await condividi(file.path);
    } finally {
      await stage.delete(recursive: true);
    }
  }

  Future<bool> _ripristinaCifrata(
    BuildContext context,
    NoteAttachmentStore store,
    BackupController backups,
    File sealed,
  ) async {
    Directory? directory;
    try {
      final stage = directory =
          await (await getTemporaryDirectory()).createTemp('planner-restore-');
      try {
        await store.existingArchiveKey();
      } on StateError {
        if (!context.mounted) return false;
        final accepted = await showRecoveryInput(
          context,
          title: 'Apri la copia cifrata',
          action: 'Verifica chiave',
          submit: (code) => store.useRecoveryCode(
            code,
            verify: (key) async {
              try {
                await const PortableEncryptedBackup().verifyKey(sealed, key);
              } on PortableBackupTooLarge {
                rethrow;
              } catch (_) {
                throw const FormatException(
                    'Chiave diversa o copia illeggibile. Controlla e riprova.');
              }
            },
          ),
        );
        if (!accepted || !context.mounted) return false;
      }
      if (!context.mounted) return false;
      final key = await store.existingArchiveKey();
      if (!context.mounted) return false;
      await _conSyncInPausa(context, () async {
        final database = await const PortableEncryptedBackup().read(
          sealed: sealed,
          staging: stage,
          blobPool: _pool(backups),
          key: key,
        );
        await backups.ripristinaEsterna(database.path);
      });
      return true;
    } on StateError catch (error) {
      if (context.mounted) _dici(context, error.message);
      return false;
    } catch (error) {
      if (context.mounted) {
        _dici(
            context,
            switch (error) {
              PortableBackupTooLarge() => error.message,
              _ when isDeviceStorageFull(error) => deviceStorageFullMessage,
              _ =>
                'Impossibile aprire la copia. Controlla la chiave o scegli un altro file.',
            });
      }
      return false;
    } finally {
      await directory?.delete(recursive: true);
    }
  }
}
