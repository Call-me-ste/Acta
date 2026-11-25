import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/notes/document_scan.dart';
import 'document_corner_editor.dart';
import 'note_camera_page.dart';

part 'document_scan_sources.dart';

Future<String?> scanNoteDocument(BuildContext context) async {
  final work =
      await (await getTemporaryDirectory()).createTemp('planner-crop-');
  try {
    if (!context.mounted) return null;
    return await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => _DocumentScanPage(work: work),
    ));
  } finally {
    await work.delete(recursive: true);
  }
}

Future<PreparedScan> _prepare(String source, String target) =>
    Isolate.run(() => prepareScanPhoto(source, target));

Future<void> _render(String source, String target,
        List<math.Point<double>> corners, bool monochrome) =>
    Isolate.run(() => renderDocumentScan(source, target, corners, monochrome));

Future<void> _renderGuide(String source, String target) =>
    Isolate.run(() => renderMonochromeGuide(source, target));

Future<String?> _selectPhoto() async {
  const picker = MethodChannel('planner/shared_files');
  final options = await picker.invokeListMethod<Map>(
    'pick',
    {'pdf': false, 'single': true, 'scanPhoto': true},
  );
  return options == null || options.isEmpty
      ? null
      : options.single['path'] as String;
}

class _DocumentScanPage extends StatefulWidget {
  const _DocumentScanPage({required this.work});
  final Directory work;

  @override
  State<_DocumentScanPage> createState() => _DocumentScanPageState();
}

class _DocumentScanPageState extends State<_DocumentScanPage> {
  final _corners = [...defaultDocumentCorners];
  final _pages = <File>[];
  Size? _size;
  File? _preview;
  File? _filteredSource;
  bool _busy = false;
  bool _monochrome = false;
  bool _detected = false;
  int _previewRevision = 0;

  String get _source => p.join(widget.work.path, 'oriented.jpg');

  Future<void> _choose({required bool camera}) => _run(() async {
        final source = camera ? await _capturePhoto() : await _selectPhoto();
        if (source == null || !mounted) return;
        try {
          final result = await _prepare(source, _source);
          await FileImage(File(_source)).evict();
          if (mounted) {
            setState(() {
              _size = Size(result.width.toDouble(), result.height.toDouble());
              _preview = null;
              _filteredSource = null;
              _detected = result.corners != null;
              _monochrome = false;
              _corners.setAll(0, result.corners ?? defaultDocumentCorners);
            });
          }
        } finally {
          await File(source).delete();
        }
      });

  Future<String?> _capturePhoto() async {
    final raw = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const NoteCameraPage(document: true),
    ));
    if (raw == null) return null;
    try {
      return await const MethodChannel('planner/document_scanner')
          .invokeMethod<String>('preparePhoto', {'path': raw});
    } finally {
      final photo = File(raw);
      if (await photo.exists()) await photo.delete();
    }
  }

  Future<void> _ensureFilteredSource() async {
    if (_filteredSource != null) return;
    final target = p.join(widget.work.path, 'mono-$_previewRevision.jpg');
    await _renderGuide(_source, target);
    _filteredSource = File(target);
  }

  Future<void> _setMonochrome(bool enabled) async {
    if (_preview != null) {
      await _showPreview(monochrome: enabled);
      return;
    }
    await _run(() async {
      setState(() => _monochrome = enabled);
      if (!enabled) return;
      try {
        await _ensureFilteredSource();
      } catch (_) {
        if (mounted) setState(() => _monochrome = false);
        rethrow;
      }
    });
  }

  Future<void> _showPreview({bool? monochrome}) => _run(() async {
        final mode = monochrome ?? _monochrome;
        final target =
            p.join(widget.work.path, 'preview-${_previewRevision++}.jpg');
        await _render(_source, target, List.of(_corners), mode);
        if (mode) await _ensureFilteredSource();
        if (mounted) {
          setState(() {
            _monochrome = mode;
            _preview = File(target);
          });
        }
      });

  void _addPage() => setState(() {
        _pages.add(_preview!);
        _size = null;
        _preview = null;
        _filteredSource = null;
      });

  Future<void> _attach() => _run(() async {
        const converter = MethodChannel('planner/document_scanner');
        final paths = [
          for (final page in _pages) page.path,
          if (_preview case final page?) page.path,
        ];
        final pdf = await converter.invokeMethod<String>(
          'capturePdf',
          {'paths': paths},
        );
        if (pdf == null) {
          throw const FormatException('Il PDF non è stato creato.');
        }
        if (mounted) Navigator.of(context).pop(pdf);
      });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
          switch (error) {
            FormatException() => error.message,
            PlatformException() =>
              error.message ?? 'Impossibile leggere la foto.',
            _ => 'Impossibile preparare la scansione. Riprova.',
          },
        )));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    final preview = _preview;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
            title: Text(preview == null
                ? 'Scansiona documento'
                : 'Anteprima pagina ${_pages.length + 1}')),
        body: SafeArea(
          child: size == null
              ? _ScanSources(
                  busy: _busy,
                  pageCount: _pages.length,
                  onCamera: () => _choose(camera: true),
                  onGallery: () => _choose(camera: false),
                  onRemove: (index) => setState(() => _pages.removeAt(index)),
                  onAttach: _attach,
                )
              : Column(
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    if (preview == null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                            _detected
                                ? 'Bordi rilevati. Controlla i quattro angoli.'
                                : 'Trascina gli angoli sui bordi. Usa + per i dettagli.',
                            textAlign: TextAlign.center),
                      ),
                    Expanded(
                      child: preview != null
                          ? Center(
                              child: Image.file(preview, fit: BoxFit.contain))
                          : DocumentCornerEditor(
                              file: _monochrome
                                  ? _filteredSource ?? File(_source)
                                  : File(_source),
                              imageSize: size,
                              corners: _corners,
                              onMoved: (index, point) {
                                final next = [..._corners]..[index] = point;
                                if (!_busy && validDocumentCorners(next)) {
                                  setState(() => _corners[index] = point);
                                }
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Bianco e nero'),
                            selected: _monochrome,
                            onSelected: _busy ? null : _setMonochrome,
                          ),
                          if (preview == null)
                            FilledButton(
                                onPressed: _busy ? null : _showPreview,
                                child: const Text('Anteprima'))
                          else ...[
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _preview = null),
                              child: const Text('Modifica bordi'),
                            ),
                            if (_pages.length < 19)
                              TextButton(
                                onPressed: _busy ? null : _addPage,
                                child: const Text('Altra pagina'),
                              ),
                            FilledButton(
                                onPressed: _busy ? null : _attach,
                                child: const Text('Allega PDF')),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
