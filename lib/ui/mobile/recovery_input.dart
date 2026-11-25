import 'package:flutter/material.dart';

import '../shared/motion.dart';

Future<bool> showRecoveryInput(
  BuildContext context, {
  required String title,
  required String action,
  required Future<void> Function(String code) submit,
}) async =>
    await showActaDialog<bool>(
      context: context,
      builder: (_) =>
          _RecoveryInput(title: title, action: action, submit: submit),
    ) ??
    false;

class _RecoveryInput extends StatefulWidget {
  const _RecoveryInput({
    required this.title,
    required this.action,
    required this.submit,
  });

  final String title;
  final String action;
  final Future<void> Function(String code) submit;

  @override
  State<_RecoveryInput> createState() => _RecoveryInputState();
}

class _RecoveryInputState extends State<_RecoveryInput> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(_code.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (error) {
          FormatException(:final message) => message,
          StateError(:final message) => message,
          _ => 'Impossibile verificare la chiave. Riprova.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: Text(widget.title),
          scrollable: true,
          content: TextField(
            controller: _code,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_busy,
            onSubmitted: (_) => _check(),
            decoration: InputDecoration(
              labelText: 'Chiave di recupero di Acta',
              errorText: _error,
              errorMaxLines: 4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: _busy ? null : _check,
              child: Text(_busy ? 'Verifica in corso…' : widget.action),
            ),
          ],
        ),
      );
}
