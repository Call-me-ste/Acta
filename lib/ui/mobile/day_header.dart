import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/design_tokens.dart';

/// L'intestazione della vista **giorno**: frecce ai lati e, in mezzo, la **data**
/// che si sta guardando.
///
/// Stessa forma dell'intestazione del mese (`MonthHeader`) e della settimana
/// (`WeekNavBar`): titolo centrato, frecce ai lati, titolo che si tocca e apre la
/// scelta di mese e anno, freccia in giù che lo dice. Prima la vista giorno non
/// diceva *niente*: si capiva che giorno era solo dalla posizione dello scorrimento,
/// ed era il difetto piu' evidente fra le tre viste.
///
/// La data e' scritta per esteso («giovedi' 17 settembre») e non abbreviata: nel
/// giorno c'e' spazio, e il giorno della settimana e' l'informazione che serve.
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.day,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime day;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Apre la scelta di mese e anno.
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final oggi = DateTime.now();
    final eOggi =
        day.year == oggi.year && day.month == oggi.month && day.day == oggi.day;

    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left, size: AppSpacing.icon),
          color: scheme.onSurfaceVariant,
          tooltip: 'Giorno precedente',
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
                    titolo(day),
                    style: theme.textTheme.titleMedium?.copyWith(
                      // «Sei su oggi» si dice col peso, non con primary: su alcune
                      // palette (verde, arancio) primary come testo non arriva a
                      // 4,5:1.
                      fontWeight: eOggi ? FontWeight.w600 : null,
                    ),
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
          tooltip: 'Giorno successivo',
        ),
      ],
    );
  }

  /// «Giovedi' 17 settembre», con l'iniziale maiuscola.
  static String titolo(DateTime day) {
    final testo = DateFormat('EEEE d MMMM', 'it_IT').format(day);
    return toBeginningOfSentenceCase(testo) ?? testo;
  }
}
