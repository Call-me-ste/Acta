import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../shared/picker_tile.dart';
import 'event_time_fields.dart';

/// La parte **evento** di un item: giorno, tutto-il-giorno e orari.
///
/// Senza stato: i valori li tiene il form (`ItemForm`), così cambiando tipo si
/// perde solo ciò che si vede, non ciò che si è scritto.
class EventSection extends StatelessWidget {
  const EventSection({
    super.key,
    required this.day,
    required this.endDay,
    required this.allDay,
    required this.start,
    required this.end,
    required this.onPickDay,
    required this.onPickEndDay,
    required this.onToggleAllDay,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final DateTime day;
  final DateTime endDay;
  final bool allDay;
  final TimeOfDay start;
  final TimeOfDay end;
  final VoidCallback onPickDay;
  final VoidCallback onPickEndDay;
  final ValueChanged<bool> onToggleAllDay;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerTile(
          icon: Icons.calendar_today_outlined,
          label: 'Giorno',
          value: localizations.formatMediumDate(day),
          onTap: onPickDay,
        ),
        // L'interruttore è una **riga di campo** come le altre: stessa altezza
        // minima, stessa etichetta attenuata, interruttore a destra. Con
        // `SwitchListTile` era alta e larga a modo suo — ed era una delle
        // incoerenze che si vedevano nel form.
        InkWell(
          onTap: () => onToggleAllDay(!allDay),
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: AppSpacing.touchTarget),
            child: Row(
              children: [
                Icon(
                  Icons.wb_sunny_outlined,
                  size: AppSpacing.icon,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Text(
                    'Tutto il giorno',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Switch(
                  value: allDay,
                  onChanged: onToggleAllDay,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
        // Con l'interruttore acceso i due orari non direbbero niente.
        if (!allDay)
          EventTimeFields(
            start: start,
            end: end,
            onPickStart: onPickStart,
            onPickEnd: onPickEnd,
          ),
        PickerTile(
          icon: Icons.event_outlined,
          label: 'Data di fine',
          value: localizations.formatMediumDate(endDay),
          onTap: onPickEndDay,
        ),
      ],
    );
  }
}
