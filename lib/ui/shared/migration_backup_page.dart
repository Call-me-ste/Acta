import 'package:flutter/material.dart';

class MigrationBackupPage extends StatefulWidget {
  const MigrationBackupPage({super.key, required this.retry});

  final Future<void> Function() retry;

  @override
  State<MigrationBackupPage> createState() => _MigrationBackupPageState();
}

class _MigrationBackupPageState extends State<MigrationBackupPage> {
  bool _retrying = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Copia di sicurezza necessaria')),
          body: SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: 1,
              itemBuilder: (context, index) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Acta non è riuscita a creare la copia prima della migrazione. '
                      'Controlla lo spazio disponibile sul telefono e riprova.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _retrying
                        ? null
                        : () async {
                            setState(() => _retrying = true);
                            try {
                              await widget.retry();
                            } finally {
                              if (mounted) setState(() => _retrying = false);
                            }
                          },
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
