part of 'sync_settings_page.dart';

class DriveBackupTile extends StatelessWidget {
  const DriveBackupTile({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController?>();
    if (sync == null) return const SizedBox.shrink();
    final last = sync.lastSyncTime;
    final status = sync.lastError ??
        (last != null
            ? 'Ultimo sync: ${formatSyncTime(last)}'
            : sync.isSupported
                ? 'Sincronizzazione facoltativa'
                : 'Non disponibile');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.cloud_outlined),
      title: const Text('Google Drive'),
      subtitle: Text(sync.isSignedIn && sync.pendingCount > 0
          ? '$status · ${sync.pendingCount} in attesa'
          : status),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const SyncSettingsPage()),
      ),
    );
  }
}

String formatSyncTime(DateTime when) {
  final hour = when.hour.toString().padLeft(2, '0');
  final minute = when.minute.toString().padLeft(2, '0');
  return '${when.day}/${when.month} $hour:$minute';
}
