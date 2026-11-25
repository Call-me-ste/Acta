import 'package:flutter/material.dart';

import '../../features/events/domain/event_occurrence.dart';
import '../../theme/design_tokens.dart';
import '../shared/event_colors.dart';
import '../shared/formatters.dart';

/// Un evento della settimana: blocco colorato con il **titolo sempre dentro**
/// (9,5 sp, ellissi) e l'orario solo nei blocchi abbastanza alti. Il testo
/// resta neutro: il fondo è la tinta dell'evento, leggibile con ogni palette.
///
/// Sta in un file suo per il tetto delle 300 righe di `week_timeline.dart`, come
/// `week_todo_block.dart`: un blocco, un file.
class WeekEventBlock extends StatelessWidget {
  const WeekEventBlock({
    super.key,
    required this.occurrence,
    required this.showTime,
    this.onTap,
  });

  final EventOccurrence occurrence;

  /// Nei blocchi alti l'orario è informazione, nei brevi è rumore.
  final bool showTime;
  final ValueChanged<EventOccurrence>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = occurrenceColor(context, occurrence);

    return Material(
      color: color.withValues(alpha: 0.32),
      borderRadius: BorderRadius.circular(AppRadius.bar),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(occurrence),
        borderRadius: BorderRadius.circular(AppRadius.bar),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Align(
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  occurrence.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppType.micro,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
                if (showTime)
                  Text(
                    formatTimeRange(occurrence.start, occurrence.end),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: AppType.nano,
                      height: 1.1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
