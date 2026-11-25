import 'package:flutter/material.dart';

import '../../features/calendar_import/domain/calendar_selection.dart';
import '../../features/calendar_import/domain/device_calendar_gateway.dart';
import '../../theme/design_tokens.dart';
import '../shared/form_section_title.dart';
import '../shared/motion.dart';

class ImportCalendars extends StatelessWidget {
  const ImportCalendars({
    super.key,
    required this.calendars,
    required this.selected,
    required this.onToggle,
    required this.onToggleAll,
  });

  final List<DeviceCalendarInfo> calendars;
  final Set<String> selected;
  final void Function(String id, bool? selected) onToggle;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final principali = [
      for (final calendar in calendars)
        if (!isSystemCalendar(calendar)) calendar,
    ]..sort(compareCalendars);
    final sistema = [
      for (final calendar in calendars)
        if (isSystemCalendar(calendar)) calendar,
    ]..sort(compareCalendars);
    final sistemaScelti =
        sistema.where((calendar) => selected.contains(calendar.id)).length;
    final gruppiPrincipali = <String, List<DeviceCalendarInfo>>{};
    for (final calendar in principali) {
      gruppiPrincipali.putIfAbsent(calendarGroupKey(calendar), () => []).add(
            calendar,
          );
    }
    final gruppiSistema = <String, List<DeviceCalendarInfo>>{};
    for (final calendar in sistema) {
      final chiave = calendarName(calendar).trim().toLowerCase();
      gruppiSistema.putIfAbsent(chiave, () => []).add(calendar);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionTitle(
          'Calendari',
          icon: Icons.calendar_month_outlined,
        ),
        if (calendars.isEmpty)
          const Text('Nessun calendario trovato sul telefono.')
        else ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onToggleAll,
              child: Text(
                selected.length == calendars.length
                    ? 'Deseleziona tutti'
                    : 'Seleziona tutti',
              ),
            ),
          ),
          if (principali.isEmpty)
            const Text('Nessun calendario personale trovato.')
          else
            for (final gruppo in gruppiPrincipali.values)
              gruppo.length == 1 ? _riga(gruppo.first) : _rigaGruppo(gruppo),
          if (sistema.isNotEmpty)
            ExpansionTile(
              expansionAnimationStyle: menuMotion(context),
              key: const ValueKey('importa-sistema'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Festività e calendari di sistema'),
              subtitle: Text(
                sistemaScelti == 0
                    ? '${sistema.length} calendari · esclusi dal one-click'
                    : '$sistemaScelti di ${sistema.length} selezionati',
              ),
              children: [
                for (final gruppo in gruppiSistema.values) _rigaGruppo(gruppo),
              ],
            ),
        ],
      ],
    );
  }

  Widget _riga(DeviceCalendarInfo calendar) {
    final sottotitolo = calendarSubtitle(calendar);
    return CheckboxListTile(
      key: ValueKey('importa-calendario-${calendar.id}'),
      contentPadding: EdgeInsets.zero,
      value: selected.contains(calendar.id),
      onChanged: (value) => onToggle(calendar.id, value),
      title: Text(calendarName(calendar)),
      subtitle: sottotitolo == null ? null : Text(sottotitolo),
    );
  }

  /// Le festività duplicate su più account (Samsung/Outlook lo fa spesso)
  /// diventano **una riga sola**: la spunta vale per tutte le copie.
  Widget _rigaGruppo(List<DeviceCalendarInfo> gruppo) {
    final tutti = gruppo.every((calendar) => selected.contains(calendar.id));
    final alcuni = gruppo.any((calendar) => selected.contains(calendar.id));
    final primo = gruppo.first;
    final account = {
      for (final calendar in gruppo)
        if ((calendar.accountName ?? '').trim().isNotEmpty)
          calendar.accountName!.trim(),
    }.join(', ');
    final sottotitolo = gruppo.length == 1
        ? calendarSubtitle(primo)
        : isLocalCalendar(primo)
            ? '${gruppo.length} calendari locali · solo su questo telefono'
            : '${gruppo.length} calendari'
                '${account.isEmpty ? '' : ' · $account'}';

    return CheckboxListTile(
      key: ValueKey('importa-gruppo-${calendarGroupKey(primo)}'),
      contentPadding: EdgeInsets.zero,
      tristate: true,
      value: tutti ? true : (alcuni ? null : false),
      onChanged: (value) {
        final attivo = value ?? !tutti;
        for (final calendar in gruppo) {
          onToggle(calendar.id, attivo);
        }
      },
      title: Text(calendarName(primo)),
      subtitle: sottotitolo == null ? null : Text(sottotitolo),
    );
  }
}

class ImportPeriodPicker extends StatelessWidget {
  const ImportPeriodPicker({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final ImportPeriod period;
  final ValueChanged<ImportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionTitle('Periodo', icon: Icons.date_range_outlined),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            for (final value in ImportPeriod.values)
              ChoiceChip(
                key: ValueKey('importa-periodo-${value.name}'),
                label: Text(value.label),
                selected: value == period,
                onSelected: (_) => onChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}
