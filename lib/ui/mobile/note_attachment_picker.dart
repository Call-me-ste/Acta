import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker;
import 'package:pdfx/pdfx.dart';

import '../../core/storage_failure.dart';
import '../../features/notes/note_attachment_store.dart';
import '../shared/motion.dart';
import 'document_scan_page.dart';
import 'note_camera_page.dart';

Future<Uint8List?> creaAnteprimaPdf(File file) async {
  final size = await file.length();
  if (size == 0) throw const FormatException('Il PDF è vuoto.');
  if (size > NoteAttachmentStore.maxPdfBytes) {
    throw const FormatException('Il PDF supera il limite di 100 MiB.');
  }
  final PdfDocument document;
  try {
    document = await PdfDocument.openFile(file.path);
  } catch (error) {
    if (isDeviceStorageFull(error)) rethrow;
    throw const FormatException(
        'Impossibile aprire il PDF. Controlla che non sia protetto o danneggiato.');
  }
  try {
    try {
      if (document.pagesCount == 0) return null;
      final page = await document.getPage(1);
      try {
        final scale =
            320 / (page.width > page.height ? page.width : page.height);
        final image = await page.render(
          width: (page.width * scale).clamp(1.0, 320.0),
          height: (page.height * scale).clamp(1.0, 320.0),
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        return image?.bytes;
      } finally {
        await page.close();
      }
    } catch (_) {
      return null;
    }
  } finally {
    await document.close();
  }
}

Future<String?> scegliAllegato(BuildContext context) {
  return showActaSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta foto'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Allega foto'),
            onTap: () => Navigator.pop(context, 'photo'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('PDF'),
            subtitle: const Text('Fino a 100 MiB per file'),
            onTap: () => Navigator.pop(context, 'pdf'),
          ),
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('Scansiona documento'),
              onTap: () => Navigator.pop(context, 'scan'),
            ),
        ],
      ),
    ),
  );
}

typedef AttachmentSelection = ({
  List<({String path, String name})> files,
  List<String> skipped
});

List<String> skippedAttachments(Map<Object?, Object?>? batch) => [
      for (final code in (batch?['skipped'] as List? ?? const []))
        switch (code) {
          'pdf_large' => 'PDF oltre 100 MiB.',
          'photo_large' => 'Foto oltre 18 MiB.',
          'device_full' => deviceStorageFullMessage,
          'selection_large' =>
            'La selezione supera 200 MiB. Aggiungi i file in più gruppi.',
          'selection_count' => 'Puoi scegliere fino a 16 file alla volta.',
          'empty' => 'File vuoto.',
          'unsupported' => 'Formato non supportato.',
          _ => 'File illeggibile. Prova a scaricarlo sul dispositivo.',
        },
    ];

String attachmentErrorMessage(Object error) => switch (error) {
      _ when isDeviceStorageFull(error) => deviceStorageFullMessage,
      FormatException(:final message) => message,
      _ => 'Impossibile aggiungere il file. Riprova.',
    };

String attachmentBatchMessage(int added, List<String> errors) =>
    '$added aggiunti, ${errors.length} esclusi. ${errors.toSet().join(' ')}';

Future<AttachmentSelection> selezionaAllegati(
    BuildContext context, String scelta) async {
  if (scelta == 'scan') {
    final path = await scanNoteDocument(context);
    return (
      files: [if (path != null) (path: path, name: 'Scansione.pdf')],
      skipped: <String>[]
    );
  }
  if (scelta == 'camera') {
    final path = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const NoteCameraPage(document: false),
    ));
    return (
      files: [if (path != null) (path: path, name: 'Foto.jpg')],
      skipped: <String>[]
    );
  }
  if (scelta == 'photo' && Platform.isAndroid) {
    final origin = await showActaSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galleria'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Gestore file'),
            onTap: () => Navigator.pop(context, 'files'),
          ),
        ]),
      ),
    );
    if (origin == null) {
      return (files: <({String path, String name})>[], skipped: <String>[]);
    }
    if (origin == 'gallery') {
      final photos = await ImagePicker().pickMultiImage(
        maxWidth: 2400,
        maxHeight: 2400,
        limit: 16,
      );
      return (
        files: [for (final file in photos) (path: file.path, name: file.name)],
        skipped: <String>[]
      );
    }
  }
  final pdf = scelta == 'pdf';
  if (Platform.isAndroid) {
    const picker = MethodChannel('planner/shared_files');
    final Map<Object?, Object?>? batch;
    try {
      batch =
          await picker.invokeMapMethod<Object?, Object?>('pick', {'pdf': pdf});
    } on PlatformException catch (error) {
      throw FormatException(error.code == 'busy'
          ? 'C’è già una selezione aperta.'
          : 'Impossibile leggere i file scelti.');
    }
    return (
      files: [
        for (final file in (batch?['files'] as List? ?? const []))
          (path: file['path'] as String, name: file['name'] as String),
      ],
      skipped: skippedAttachments(batch)
    );
  }
  const photos = XTypeGroup(
    label: 'Foto',
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
  );
  const documents = XTypeGroup(
    label: 'PDF',
    extensions: ['pdf'],
    mimeTypes: ['application/pdf'],
  );
  final files = await openFiles(acceptedTypeGroups: [pdf ? documents : photos]);
  return (
    files: [for (final file in files) (path: file.path, name: file.name)],
    skipped: <String>[]
  );
}
