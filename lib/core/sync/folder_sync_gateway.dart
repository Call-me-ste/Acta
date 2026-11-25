import 'dart:io';

import 'sync_attachment_transport.dart';
import 'sync_gateway.dart';

/// Gateway su una cartella locale.
///
/// Serve a tre cose: i test (nessuna rete, nessun account), l'export/import su
/// disco, e il banco di prova del formato prima che esista il client Drive.
class FolderSyncGateway implements SyncGateway, SyncAttachmentTransport {
  FolderSyncGateway(String root) : _root = Directory(root);

  final Directory _root;

  @override
  Future<List<String>> list(String prefix) async {
    if (!await _root.exists()) return const [];

    final found = <String>[];
    await for (final entry in _root.list(recursive: true, followLinks: false)) {
      if (entry is! File) continue;
      final relative = _relative(entry.path);
      if (relative.startsWith(prefix)) found.add(relative);
    }
    found.sort();
    return found;
  }

  @override
  Future<List<int>?> read(String path) async {
    final file = _resolve(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    final file = _resolve(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete(String path) async {
    final file = _resolve(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<bool> hasAttachment(String path) => _resolve(path).exists();

  @override
  Future<void> uploadAttachment(String path, File source) =>
      _copyAtomically(source, _resolve(path));

  @override
  Future<bool> downloadAttachment(String path, File target) async {
    final source = _resolve(path);
    if (!await source.exists()) return false;
    await _copyAtomically(source, target);
    return true;
  }

  Future<void> _copyAtomically(File source, File target) async {
    await target.parent.create(recursive: true);
    final directory = await target.parent.createTemp('.planner-sync-');
    try {
      final staging = await source.copy(
        File.fromUri(directory.uri.resolve('payload')).path,
      );
      await staging.rename(target.path);
    } finally {
      await directory.delete(recursive: true);
    }
  }

  String _relative(String absolutePath) {
    final normalized = absolutePath.replaceAll(r'\', '/');
    final root =
        _root.path.replaceAll(r'\', '/').replaceFirst(RegExp(r'/+$'), '');
    return normalized.startsWith('$root/')
        ? normalized.substring(root.length + 1)
        : normalized;
  }

  /// Il gateway scrive **dentro** la sua cartella e basta: un percorso che
  /// risale (`../`) viene rifiutato invece di essere normalizzato in silenzio.
  File _resolve(String path) {
    if (path.isEmpty || path.contains('..')) {
      throw ArgumentError('Percorso non valido per il gateway: "$path"');
    }
    final separator = Platform.pathSeparator;
    return File('${_root.path}$separator${path.replaceAll('/', separator)}');
  }
}
