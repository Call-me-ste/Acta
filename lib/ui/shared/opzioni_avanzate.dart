import 'package:flutter/material.dart';

import 'motion.dart';

/// Dettagli non necessari per l'uso quotidiano, chiusi all'apertura.
class OpzioniAvanzate extends StatelessWidget {
  const OpzioniAvanzate({
    super.key,
    required this.children,
    this.nota,
  });

  final List<Widget> children;
  final String? nota;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        expansionAnimationStyle: menuMotion(context),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('Opzioni avanzate'),
        subtitle: nota == null ? null : Text(nota!),
        children: children,
      );
}
