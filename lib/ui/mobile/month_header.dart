import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/design_tokens.dart';

/// L'intestazione della vista mese: frecce ai lati e, in mezzo, il mese e l'anno
/// **cliccabili**.
///
/// Sta qui e non dentro `table_calendar` perche' il calendario disegna la sua
/// intestazione ma non offre un callback sul tocco del titolo: con una mia intestazione
/// il tocco c'e' (`onPick`), il bersaglio e' grande come deve (48 dp) e il testo e' quello
/// del tema.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    super.key,
    required this.focusedDay,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime focusedDay;
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
          tooltip: 'Mese precedente',
        ),
        Expanded(
          child: TextButton(
            onPressed: onPick,
            // Il controllo e' un pulsante, e si deve sentire: il titolo dice dove
            // sei, la freccia in giù dice che si puo' cambiare.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _titolo(focusedDay),
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
          tooltip: 'Mese successivo',
        ),
      ],
    );
  }

  /// «settembre 2026»: mese esteso e anno, con l'iniziale maiuscola.
  static String _titolo(DateTime day) {
    final testo = DateFormat.yMMMM('it_IT').format(day);
    return toBeginningOfSentenceCase(testo) ?? testo;
  }
}
