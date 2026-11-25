import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Orari affiancati con bersagli distinti, anche allargando il testo.
class EventTimeFields extends StatelessWidget {
  const EventTimeFields({
    super.key,
    required this.start,
    required this.end,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);

    Widget campo(String etichetta, TimeOfDay ora, VoidCallback scegli) {
      return Expanded(
        child: Material(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.small),
            onTap: scegli,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(minHeight: AppSpacing.touchTarget),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      etichetta,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      localizations.formatTimeOfDay(ora),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          campo('Inizio', start, onPickStart),
          const SizedBox(width: AppSpacing.s),
          campo('Fine', end, onPickEnd),
        ],
      ),
    );
  }
}
