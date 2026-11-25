import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'day_timeline.dart';

/// La colonna degli orari, a sinistra delle viste a griglia (settimana, giorno).
///
/// Sta in un file suo perche' la usano due viste: e' la **stessa** colonna, e
/// quindi la stessa larghezza (`WeekView.gutter`), altrimenti le due griglie
/// sarebbero allineate in modo diverso.
class HourLabels extends StatelessWidget {
  const HourLabels({super.key});

  /// La larghezza della colonna degli orari. Le intestazioni dei giorni e la
  /// striscia dei «tutto il giorno» si indentano di questa misura: e' quello che
  /// tiene le date sopra le loro colonne.
  static const double width = AppSpacing.hourGutter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var hour = 0; hour < 24; hour++)
          SizedBox(
            height: DayTimeline.defaultHourHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
