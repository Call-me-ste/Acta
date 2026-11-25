import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../shared/motion.dart';
import '../../core/sync/drive_failure.dart';
import '../../core/storage_failure.dart';
import '../../features/notes/note_attachment_store.dart';
import '../../theme/design_tokens.dart';

class NoteAttachmentTile extends StatefulWidget {
  const NoteAttachmentTile({
    super.key,
    required this.store,
    required this.noteId,
    required this.id,
    this.onRemove,
    this.onRename,
  });

  final NoteAttachmentStore? store;
  final String noteId;
  final String id;
  final VoidCallback? onRemove;
  final VoidCallback? onRename;

  @override
  State<NoteAttachmentTile> createState() => _NoteAttachmentTileState();
}

class _NoteAttachmentTileState extends State<NoteAttachmentTile> {
  late var _loading = _load();
  bool _working = false;

  Future<({NoteAttachment attachment, Uint8List? preview, bool local})?>
      _load() async {
    final store = widget.store;
    final attachment = await store?.read(widget.noteId, widget.id);
    if (attachment == null) return null;
    final local = await store!.blobFile('${attachment.blobId}.blob').exists();
    final work =
        await (await getTemporaryDirectory()).createTemp('planner-thumb-');
    try {
      final image = await store.open(attachment, work, thumbnail: true);
      return (
        attachment: attachment,
        preview: await image.readAsBytes(),
        local: local
      );
    } catch (_) {
      return (attachment: attachment, preview: null, local: local);
    } finally {
      await work.delete(recursive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loading,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          final waiting = snapshot.connectionState != ConnectionState.done;
          return ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(
                waiting ? 'Caricamento allegato…' : 'Allegato non disponibile'),
            trailing: waiting
                ? null
                : IconButton(
                    tooltip: 'Riprova',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() => _loading = _load()),
                  ),
            onLongPress: widget.onRemove,
          );
        }
        final attachment = data.attachment;
        final preview = data.preview;
        return Card(
          child: ListTile(
            onTap: _working ? null : () => _manage(attachment, 'open'),
            leading: preview != null
                ? Image.memory(preview,
                    width: 48, height: 48, fit: BoxFit.cover)
                : Icon(attachment.kind == NoteAttachmentKind.pdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined),
            title: Text(attachment.name,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: data.local
                ? null
                : Text(widget.store?.remote?.call() == null
                    ? 'Originale non presente sul dispositivo'
                    : 'Tocca per scaricare da Drive'),
            trailing: PopupMenuButton<String>(
              popUpAnimationStyle: menuMotion(context),
              tooltip: 'Azioni allegato',
              enabled: !_working,
              onSelected: (action) => _manage(attachment, action),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'open', child: Text('Apri')),
                if (widget.onRemove != null)
                  const PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                const PopupMenuItem(value: 'share', child: Text('Condividi')),
                if (widget.onRemove != null)
                  const PopupMenuItem(value: 'remove', child: Text('Rimuovi')),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _manage(NoteAttachment attachment, String action) async {
    if (_working) return;
    if (action == 'remove') {
      widget.onRemove?.call();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _working = true);
    try {
      if (action == 'rename') {
        final name = await showActaDialog<String>(
          context: context,
          builder: (_) => _RenameAttachmentDialog(attachment.name),
        );
        if (name != null && mounted) {
          await widget.store!.rename(attachment, name);
          if (mounted) {
            widget.onRename?.call();
            setState(() => _loading = _load());
          }
        }
        return;
      }
      final work =
          await (await getTemporaryDirectory()).createTemp('planner-open-');
      try {
        final file = await widget.store!.open(attachment, work);
        if (!mounted) return;
        setState(() => _loading = _load());
        if (action == 'share') {
          final pdf = attachment.kind == NoteAttachmentKind.pdf;
          final prefix = await file.openRead(0, 1).first;
          final png = !pdf && prefix.first == 137;
          final extension = pdf ? '.pdf' : (png ? '.png' : '.jpg');
          final mime =
              pdf ? 'application/pdf' : (png ? 'image/png' : 'image/jpeg');
          final stem = attachment.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
          final name = '${stem.isEmpty ? 'Allegato' : stem}$extension';
          final named =
              await file.rename('${work.path}${Platform.pathSeparator}$name');
          await SharePlus.instance.share(ShareParams(
            files: [XFile(named.path, mimeType: mime)],
          ));
        } else {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) =>
                _AttachmentViewer(attachment: attachment, file: file),
          ));
        }
      } finally {
        await work.delete(recursive: true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(switch (error) {
            _ when isDeviceStorageFull(error) => deviceStorageFullMessage,
            AttachmentUnavailable() =>
              'Originale non trovato. Controlla Drive o un’altra copia.',
            SecretBoxAuthenticationError() ||
            FormatException() =>
              'L’allegato non è leggibile. Prova a recuperarlo da una copia.',
            SocketException() ||
            DriveFailure(kind: DriveFailureKind.temporary) =>
              'Impossibile raggiungere Drive. Riprova.',
            _ => 'Impossibile aprire o modificare l’allegato. Riprova.',
          })),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class _RenameAttachmentDialog extends StatefulWidget {
  const _RenameAttachmentDialog(this.name);

  final String name;

  @override
  State<_RenameAttachmentDialog> createState() =>
      _RenameAttachmentDialogState();
}

class _RenameAttachmentDialogState extends State<_RenameAttachmentDialog> {
  late final _controller = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Rinomina allegato'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 180,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () {
              final value = _controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Salva'),
          ),
        ],
      );
}

class _AttachmentViewer extends StatefulWidget {
  const _AttachmentViewer({required this.attachment, required this.file});

  final NoteAttachment attachment;
  final File file;

  @override
  State<_AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<_AttachmentViewer> {
  PdfController? _pdf;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.kind == NoteAttachmentKind.pdf) {
      _pdf = PdfController(document: PdfDocument.openFile(widget.file.path));
    }
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pdf = _pdf;
    return Scaffold(
      appBar: AppBar(title: Text(widget.attachment.name)),
      body: pdf != null
          ? PdfView(controller: pdf)
          : Center(
              child: InteractiveViewer(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  child: Image.file(widget.file),
                ),
              ),
            ),
    );
  }
}
