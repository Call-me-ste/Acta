import 'package:flutter/material.dart';

import '../../features/events/domain/event_occurrence.dart';
import '../../theme/design_tokens.dart';
import '../shared/event_colors.dart';
import '../shared/formatters.dart';

/// Un evento nella griglia della vista giorno: la barra colorata porta il
/// colore, il testo resta neutro — così è leggibile con qualunque palette,
/// senza calcolare un contrasto per ogni tinta scelta dall'utente.
///
/// Sta in un file suo per il tetto delle 300 righe di `day_timeline.dart`.
class DayEventBlock extends StatelessWidget {
  const DayEventBlock({
    super.key,
    required this.occurrence,
    required this.compact,
    this.onTap,
  });

  final EventOccurrence occurrence;

  /// Basso nella giornata: solo il titolo, l'orario non ci sarebbe.
  final bool compact;
  final ValueChanged<EventOccurrence>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = occurrenceColor(context, occurrence);

    return Material(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(occurrence),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      occurrence.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium,
                    ),
                    if (!compact)
                      Text(
                        formatTimeRange(occurrence.start, occurrence.end),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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
