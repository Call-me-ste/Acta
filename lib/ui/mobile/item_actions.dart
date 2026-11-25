import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class ItemActions extends StatelessWidget {
  const ItemActions({super.key, required this.onSave});

  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onSave,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.touchTarget),
        ),
        child: const Text('Salva'),
      );
}
