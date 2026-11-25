import 'package:flutter/material.dart';

import '../../features/recurrence/domain/recurrence_label.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../theme/design_tokens.dart';
import 'form_section_title.dart';

/// Scelta della ricorrenza, condivisa dal form evento e da quello todo.
///
/// I preset sono le frasi che si usano davvero ("ogni giorno", "feriali",
/// "ogni lun, mer, ven"); l'etichetta sotto è **derivata** dalla regola, così
/// quello che si legge è esattamente quello che verrà salvato.
class RecurrenceField extends StatefulWidget {
  const RecurrenceField({
    super.key,
    required this.rule,
    required this.anchor,
    required this.onChanged,
    this.showTitle = true,
    this.closeOnSelect = false,
  });

  final RecurrenceRule? rule;

  /// Data di partenza della serie: serve all'etichetta ("ogni mese il 15") e al
  /// giorno proposto quando si scelgono i giorni a mano.
  final DateTime anchor;

  final ValueChanged<RecurrenceRule?> onChanged;

  /// Il titolo di sezione: si spegne quando il campo vive dentro un foglio che
  /// ha già il suo.
  final bool showTitle;

  /// Nel foglio, una scelta standard chiude subito — come Promemoria e Suono.
  /// «Giorni personalizzati» resta aperto perché lì si sceglie più di un giorno.
  final bool closeOnSelect;

  @override
  State<RecurrenceField> createState() => _RecurrenceFieldState();
}

enum _Mode { none, daily, weekdays, weekly, biweekly, custom, monthly, yearly }

class _RecurrenceFieldState extends State<RecurrenceField> {
  late _Mode _mode;
  late Set<int> _weekdays;

  @override
  void initState() {
    super.initState();
    _mode = _modeOf(widget.rule);
    _weekdays = widget.rule != null && widget.rule!.weekdays.isNotEmpty
        ? {...widget.rule!.weekdays}
        : {widget.anchor.weekday};
  }

  static _Mode _modeOf(RecurrenceRule? rule) {
    if (rule == null) return _Mode.none;
    return switch (rule.frequency) {
      RecurrenceFrequency.daily => _Mode.daily,
      RecurrenceFrequency.monthly => _Mode.monthly,
      RecurrenceFrequency.yearly => _Mode.yearly,
      RecurrenceFrequency.weekly => switch (rule.weekdays) {
          final days when days.isEmpty =>
            // Solo l'intervallo 2 ha un preset: gli altri restano comunque
            // gestiti (l'etichetta sotto dice la regola vera).
            rule.interval == 2 ? _Mode.biweekly : _Mode.weekly,
          final days
              when days.length == Weekdays.mondayToFriday.length &&
                  days.containsAll(Weekdays.mondayToFriday) =>
            _Mode.weekdays,
          _ => _Mode.custom,
        },
    };
  }

  RecurrenceRule? _ruleFor(_Mode mode) {
    return switch (mode) {
      _Mode.none => null,
      _Mode.daily => const RecurrenceRule(frequency: RecurrenceFrequency.daily),
      _Mode.weekdays => const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          weekdays: Weekdays.mondayToFriday,
        ),
      _Mode.weekly =>
        const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
      _Mode.biweekly => const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
        ),
      _Mode.custom => RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          weekdays: _weekdays.isEmpty ? {widget.anchor.weekday} : _weekdays,
        ),
      _Mode.monthly =>
        const RecurrenceRule(frequency: RecurrenceFrequency.monthly),
      _Mode.yearly =>
        const RecurrenceRule(frequency: RecurrenceFrequency.yearly),
    };
  }

  static const List<(_Mode, String)> _voci = [
    (_Mode.none, 'Non si ripete'),
    (_Mode.daily, 'Ogni giorno'),
    (_Mode.weekdays, 'Feriali'),
    (_Mode.weekly, 'Ogni settimana'),
    (_Mode.biweekly, 'Ogni 2 settimane'),
    (_Mode.custom, 'Giorni personalizzati…'),
    (_Mode.monthly, 'Ogni mese'),
    (_Mode.yearly, 'Ogni anno'),
  ];

  void _select(_Mode mode) {
    setState(() => _mode = mode);
    widget.onChanged(_ruleFor(mode));
    if (widget.closeOnSelect && mode != _Mode.custom) {
      Navigator.of(context).maybePop();
    }
  }

  void _toggleDay(int weekday) {
    setState(() {
      if (!_weekdays.remove(weekday)) _weekdays.add(weekday);
    });
    widget.onChanged(_ruleFor(_Mode.custom));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = recurrenceLabel(widget.rule, anchor: widget.anchor);

    // Il foglio è già scorrevole, ma il campo si usa anche da solo nei test e
    // in un contenitore basso: così l'elenco non trabocca mai. Dentro il foglio
    // il genitore dà altezza non vincolata e resta lui a scorrere.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showTitle)
            const FormSectionTitle('Ricorrenza', icon: Icons.repeat),
          // Stessa forma di Promemoria e Suono: **elenco a righe**, con la spunta
          // a destra. Niente chip affiancate: erano un'altra grammatica.
          for (final voce in _voci)
            ListTile(
              key: ValueKey('recurrence-${voce.$1.name}'),
              contentPadding: EdgeInsets.zero,
              title: Text(voce.$2),
              trailing: _mode == voce.$1
                  ? Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                    )
                  : null,
              onTap: () => _select(voce.$1),
            ),
          if (_mode == _Mode.custom) ...[
            const Divider(height: AppSpacing.l),
            Text(
              'Giorni',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (var weekday = 1; weekday <= 7; weekday++)
              CheckboxListTile(
                key: ValueKey('recurrence-day-$weekday'),
                contentPadding: EdgeInsets.zero,
                value: _weekdays.contains(weekday),
                onChanged: (_) => _toggleDay(weekday),
                title: Text(_long(weekday)),
              ),
          ],
          if (label.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              label,
              key: const ValueKey('recurrence-label'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  static String _long(int weekday) => switch (weekday) {
        1 => 'Lunedì',
        2 => 'Martedì',
        3 => 'Mercoledì',
        4 => 'Giovedì',
        5 => 'Venerdì',
        6 => 'Sabato',
        _ => 'Domenica',
      };
}
