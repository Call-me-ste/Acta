import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/design_tokens.dart';
import '../shared/form_sheet.dart';
import 'month_picker_cells.dart';
import 'year_strip.dart';

/// La scelta di una **settimana**: anno, mese e poi la settimana desiderata.
///
/// Perche' un elenco di settimane e non un calendario: la settimana non ha un
/// numero che l'utente ricordi, ma ha un **intervallo** («8 – 14 set») che si
/// riconosce a colpo d'occhio; e non esiste un modo di "toccare una settimana"
/// dentro una griglia di giorni. Il calendario di AOSP fa esattamente questo:
/// una lista di settimane con i giorni selezionabili (`SimpleDayPickerFragment`,
/// «displays a titled list of weeks with selectable days»).
///
/// Il mese si cambia dalle freccette accanto al titolo e l'anno dalla striscia:
/// due modi diversi perche' sono due distanze diverse (un mese e' un passo, dieci
/// anni sono un salto). Toccare una settimana porta li' e chiude.
Future<DateTime?> showWeekPicker(
  BuildContext context, {
  required DateTime initial,
  DateTime? today,
}) {
  return showFormSheet<DateTime>(
    context,
    (sheetContext) => WeekPickerSheet(initial: initial, today: today),
  );
}

/// Il contenuto del foglio (pubblico per i test).
class WeekPickerSheet extends StatefulWidget {
  const WeekPickerSheet({super.key, required this.initial, this.today});

  /// Un giorno qualunque della settimana in cui si e' adesso.
  final DateTime initial;

  /// Il giorno "oggi" (nei test si fissa).
  final DateTime? today;

  @override
  State<WeekPickerSheet> createState() => _WeekPickerSheetState();
}

class _WeekPickerSheetState extends State<WeekPickerSheet> {
  late DateTime _mese = DateTime(widget.initial.year, widget.initial.month);

  DateTime get _oggi => widget.today ?? DateTime.now();

  /// I lunedi' delle settimane che **toccano** il mese: la prima puo' cominciare
  /// nel mese prima e l'ultima finire in quello dopo, ed e' giusto cosi' — sono
  /// le settimane che si vedono stando in quel mese.
  List<DateTime> get _settimane {
    final primo = DateTime(_mese.year, _mese.month, 1);
    final ultimo = DateTime(_mese.year, _mese.month + 1, 0);
    final lunedi =
        DateTime(primo.year, primo.month, primo.day + 1 - primo.weekday);

    final elenco = <DateTime>[];
    for (var giorno = lunedi;
        !giorno.isAfter(ultimo);
        giorno = DateTime(giorno.year, giorno.month, giorno.day + 7)) {
      elenco.add(giorno);
    }
    return elenco;
  }

  void _cambiaMese(int passi) {
    setState(() => _mese = DateTime(_mese.year, _mese.month + passi));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settimane = _settimane;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Vai a', style: theme.textTheme.titleLarge),
                ),
                TextButton.icon(
                  onPressed: () {
                    final oggi = _oggi;
                    Navigator.of(context).pop(
                      DateTime(oggi.year, oggi.month, oggi.day),
                    );
                  },
                  icon: const Icon(Icons.today, size: 18),
                  label: const Text('Oggi'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),

            YearStrip(
              anno: _mese.year,
              annoOggi: _oggi.year,
              onAnno: (anno) =>
                  setState(() => _mese = DateTime(anno, _mese.month)),
            ),
            const SizedBox(height: AppSpacing.s),

            // Il mese: freccette e titolo, come l'intestazione della settimana.
            Row(
              children: [
                IconButton(
                  onPressed: () => _cambiaMese(-1),
                  icon: const Icon(Icons.chevron_left, size: 22),
                  color: scheme.onSurfaceVariant,
                  tooltip: 'Mese precedente',
                ),
                Expanded(
                  child: Text(
                    _titolo(_mese),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _cambiaMese(1),
                  icon: const Icon(Icons.chevron_right, size: 22),
                  color: scheme.onSurfaceVariant,
                  tooltip: 'Mese successivo',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),

            // L'elenco delle settimane di quel mese.
            for (final lunedi in settimane)
              WeekRow(
                monday: lunedi,
                scelto: _stessaSettimana(lunedi, widget.initial),
                oggi: _stessaSettimana(lunedi, _oggi),
                onTap: () => Navigator.of(context).pop(lunedi),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tocca una settimana per andarci',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Se due date cadono nella stessa settimana (che comincia di lunedi').
  static bool _stessaSettimana(DateTime a, DateTime b) {
    final lunediA = DateTime(a.year, a.month, a.day + 1 - a.weekday);
    final lunediB = DateTime(b.year, b.month, b.day + 1 - b.weekday);
    return lunediA.year == lunediB.year &&
        lunediA.month == lunediB.month &&
        lunediA.day == lunediB.day;
  }

  static String _titolo(DateTime mese) {
    final testo = DateFormat.yMMMM('it_IT').format(mese);
    return toBeginningOfSentenceCase(testo) ?? testo;
  }
}
