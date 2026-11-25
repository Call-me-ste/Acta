part of 'backup_page.dart';

extension _BackupFileReader on BackupPage {
  Future<Map<String, String>?> _leggiCopia(BuildContext context) async {
    const channel = MethodChannel('planner/backup');
    if (await channel.invokeMethod<bool>('scegliFile') != true) return null;
    if (!context.mounted) {
      await channel.invokeMethod<void>('annullaLettura');
      return null;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          scrollable: true,
          title: const Text('Lettura della copia'),
          content: const LinearProgressIndicator(),
          actions: [
            TextButton(
              onPressed: () => channel.invokeMethod<void>('annullaLettura'),
              child: const Text('Annulla'),
            ),
          ],
        ),
      ),
    );
    unawaited(navigator.push(route));
    try {
      return await channel.invokeMapMethod<String, String>('leggiFile', {
        'maximumBytes': PortableEncryptedBackup.maximumFileSize,
      });
    } finally {
      if (route.isActive) navigator.removeRoute(route);
    }
  }

  Future<void> _conSyncInPausa(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final sync = context.read<SyncController?>();
    await (sync == null ? action() : sync.whileRestoring(action));
  }
}

String _backupPickerMessage(String code) => switch (code) {
      'too_large' => 'La copia supera il limite supportato da Acta.',
      'device_full' => deviceStorageFullMessage,
      'busy' => 'È già aperta una selezione. Chiudila e riprova.',
      _ => 'Impossibile leggere il file. Prova a scaricarlo sul dispositivo.',
    };
