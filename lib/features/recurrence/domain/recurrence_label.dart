import 'recurrence_rule.dart';

/// Come si legge una ricorrenza a schermo: "ogni giorno", "ogni lun-ven"…
///
/// L'etichetta si **deriva** dalla regola invece di essere un campo a parte:
/// due rappresentazioni della stessa cosa possono divergere, una sola no.
String recurrenceLabel(RecurrenceRule? rule, {required DateTime anchor}) {
  if (rule == null) return '';

  final interval = rule.interval;
  final base = switch (rule.frequency) {
    RecurrenceFrequency.daily =>
      interval > 1 ? 'ogni $interval giorni' : 'ogni giorno',
    RecurrenceFrequency.weekly => _weeklyLabel(rule, anchor),
    RecurrenceFrequency.monthly => interval > 1
        ? 'ogni $interval mesi il ${anchor.day}'
        : 'ogni mese il ${anchor.day}',
    RecurrenceFrequency.yearly =>
      interval > 1 ? 'ogni $interval anni' : 'ogni anno',
  };

  // COUNT e UNTIL sono due modi di finire: se ci sono entrambi si leggono in
  // fila invece di escludersi a vicenda.
  var label = base;
  final count = rule.count;
  if (count != null) label = '$label, $count volte';
  final until = rule.until;
  if (until != null) {
    label = '$label fino al ${until.day}/${until.month}/${until.year}';
  }
  return label;
}

String _weeklyLabel(RecurrenceRule rule, DateTime anchor) {
  final interval = rule.interval;
  if (rule.weekdays.isEmpty) {
    return interval > 1 ? 'ogni $interval settimane' : 'ogni settimana';
  }

  final days = rule.weekdays.toList()..sort();
  final daysPart =
      days.toSet().containsAll(Weekdays.mondayToFriday) && days.length == 5
          ? 'lun-ven'
          : days.length == 1
              ? _weekdayLong(days.first)
              : days.map(_weekdayShort).join(', ');
  // Con l'intervallo serve la preposizione: "ogni 2 settimane il lunedì";
  // senza, la forma corta resta quella di sempre: "ogni lun-ven".
  return interval > 1
      ? 'ogni $interval settimane il $daysPart'
      : 'ogni $daysPart';
}

String _weekdayShort(int weekday) => switch (weekday) {
      1 => 'lun',
      2 => 'mar',
      3 => 'mer',
      4 => 'gio',
      5 => 'ven',
      6 => 'sab',
      _ => 'dom',
    };

String _weekdayLong(int weekday) => switch (weekday) {
      1 => 'lunedì',
      2 => 'martedì',
      3 => 'mercoledì',
      4 => 'giovedì',
      5 => 'venerdì',
      6 => 'sabato',
      _ => 'domenica',
    };
