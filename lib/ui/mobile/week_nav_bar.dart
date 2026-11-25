import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// L'intestazione della **settimana**: frecce ai lati e, in mezzo, l'intervallo
/// dei giorni — tappabile per scegliere mese e anno.
///
/// Stessa forma e stesso peso dell'intestazione del mese (`MonthHeader`): titolo
/// centrato, frecce ai lati, titolo che si tocca e freccia in giù che lo dice.
/// Prima erano due comandi diversi (qui freccette e un testo morto): una regola
/// sola e' una cosa sola da imparare.
class WeekNavBar extends StatelessWidget {
  const WeekNavBar({
    super.key,
    required this.weekStart,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime weekStart;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Apre la scelta di mese e anno.
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left, size: AppSpacing.icon),
          color: scheme.onSurfaceVariant,
          tooltip: 'Settimana precedente',
        ),
        Expanded(
          child: TextButton(
            onPressed: onPick,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    intervallo(weekStart),
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.expand_more,
                    size: AppSpacing.iconSmall, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, size: AppSpacing.icon),
          color: scheme.onSurfaceVariant,
          tooltip: 'Settimana successiva',
        ),
      ],
    );
  }

  /// «14 – 20 set», oppure con due mesi quando la settimana li scavalca.
  static String intervallo(DateTime weekStart) {
    final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
    final primo = _mesi[weekStart.month];
    if (weekStart.month == end.month) {
      return '${weekStart.day} – ${end.day} $primo';
    }
    return '${weekStart.day} $primo – ${end.day} ${_mesi[end.month]}';
  }

  static const Map<int, String> _mesi = {
    1: 'gen',
    2: 'feb',
    3: 'mar',
    4: 'apr',
    5: 'mag',
    6: 'giu',
    7: 'lug',
    8: 'ago',
    9: 'set',
    10: 'ott',
    11: 'nov',
    12: 'dic',
  };
}
