import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class NoteCameraPage extends StatefulWidget {
  const NoteCameraPage({super.key, required this.document});

  final bool document;

  @override
  State<NoteCameraPage> createState() => _NoteCameraPageState();
}

class _NoteCameraPageState extends State<NoteCameraPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
  int _generation = 0;
  String? _error;
  bool _taking = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    final generation = ++_generation;
    CameraController? camera;
    try {
      final devices = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (devices.isEmpty) throw CameraException('no_camera', null);
      final device = devices.firstWhere(
        (d) => d.lensDirection == CameraLensDirection.back,
        orElse: () => devices.first,
      );
      camera =
          CameraController(device, ResolutionPreset.high, enableAudio: false);
      await camera.initialize();
      if (!mounted || generation != _generation) {
        await camera.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _error = null;
      });
    } catch (error) {
      await camera?.dispose();
      if (mounted && generation == _generation) {
        final permission =
            error is CameraException && error.code.startsWith('CameraAccess');
        setState(() => _error = permission
            ? 'Consenti a Planner di usare la fotocamera nelle Impostazioni di Android.'
            : 'Fotocamera non disponibile. Riprova.');
      }
    } finally {
      _opening = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _camera == null &&
        _error == null) {
      unawaited(_open());
    } else if (state == AppLifecycleState.inactive && _camera != null) {
      final camera = _camera;
      _generation++;
      setState(() => _camera = null);
      unawaited(camera!.dispose());
    }
  }

  Future<void> _take(CameraController camera) async {
    setState(() => _taking = true);
    try {
      final file = await camera.takePicture();
      if (mounted) {
        Navigator.pop(context, file.path);
      } else {
        await File(file.path).delete();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scatto non riuscito. Riprova.')),
        );
      }
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    final camera = _camera;
    if (camera != null) unawaited(camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.document ? 'Scatta documento' : 'Scatta foto')),
      body: SafeArea(
        child: camera == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
              )
            : Column(
                children: [
                  Expanded(child: Center(child: CameraPreview(camera))),
                  if (widget.document)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Inquadra il foglio per intero.'),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      onPressed: _taking ? null : () => _take(camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Scatta'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
