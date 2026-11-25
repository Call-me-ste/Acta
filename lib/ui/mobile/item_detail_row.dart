import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Una riga della scheda dettaglio: icona e testo, con lo stesso passo.
class ItemDetailRow extends StatelessWidget {
  const ItemDetailRow({
    super.key,
    required this.icona,
    required this.testo,
  });

  final IconData icona;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icona,
            size: AppSpacing.icon,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Text(
              testo,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
