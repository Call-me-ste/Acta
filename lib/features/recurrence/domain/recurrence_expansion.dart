import 'recurrence_rule.dart';

/// Quante occorrenze si generano al massimo in una sola espansione.
///
/// Non è un limite di prodotto: è una rete contro un ciclo che non termina se
/// una regola o una finestra arrivano storte. In v2 il tetto era 500 con
/// semantica di prodotto, e tagliava in silenzio.
const int maxOccurrencesPerExpansion = 1000;

/// Le date in cui cade una regola dentro `[rangeStart, rangeEnd]`, estremi
/// inclusi.
///
/// Si parte da `start` ma si **salta** aritmeticamente fino alla finestra: una
/// regola nata anni prima non deve consumare il tetto per arrivare a oggi, che è
/// esattamente il modo in cui una finestra grande verrebbe troncata in silenzio.
List<DateTime> expandOccurrences(
  RecurrenceRule rule, {
  required DateTime start,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final first = _dayOnly(start);
  final from = _dayOnly(rangeStart);
  final to = _dayOnly(rangeEnd);
  if (to.isBefore(from)) return const [];

  final limit = switch (rule.until) {
    null => to,
    final until when _dayOnly(until).isBefore(to) => _dayOnly(until),
    _ => to,
  };
  if (limit.isBefore(from)) return const [];

  return switch (rule.frequency) {
    RecurrenceFrequency.daily => _daily(rule, first, from, limit),
    RecurrenceFrequency.weekly => _weekly(rule, first, from, limit),
    RecurrenceFrequency.monthly => _monthly(rule, first, from, limit),
    RecurrenceFrequency.yearly => _yearly(rule, first, from, limit),
  };
}

List<DateTime> _daily(
  RecurrenceRule rule,
  DateTime first,
  DateTime from,
  DateTime limit,
) {
  final interval = rule.interval;
  final count = rule.count;
  final dates = <DateTime>[];

  // Con COUNT il conteggio parte dalla **prima** occorrenza della serie, quindi
  // quelle prima della finestra consumano il budget: non si può saltare
  // aritmeticamente alla finestra come si fa senza COUNT.
  var current = first;
  if (count == null && current.isBefore(from)) {
    final elapsed = _daysBetween(first, from);
    // La prima data della griglia (prima + k*intervallo) dentro la finestra:
    // arrotondo per eccesso, non per difetto.
    current =
        _addDays(first, ((elapsed + interval - 1) ~/ interval) * interval);
  }

  final cap = count ?? maxOccurrencesPerExpansion;
  var generated = 0;
  while (!current.isAfter(limit) && generated < cap) {
    generated++;
    if (!current.isBefore(from)) dates.add(current);
    current = _addDays(current, interval);
  }
  return dates;
}

List<DateTime> _weekly(
  RecurrenceRule rule,
  DateTime first,
  DateTime from,
  DateTime limit,
) {
  final interval = rule.interval;
  final count = rule.count;
  final dates = <DateTime>[];
  final cap = count ?? maxOccurrencesPerExpansion;
  var generated = 0;

  if (rule.weekdays.isEmpty) {
    // "Ogni N settimane" = lo stesso giorno della data di partenza, ogni N
    // settimane dalla prima.
    var current = first;
    if (count == null && current.isBefore(from)) {
      final elapsed = _daysBetween(first, from);
      final steps = (elapsed + 7 * interval - 1) ~/ (7 * interval);
      current = _addDays(first, steps * 7 * interval);
    }
    while (!current.isAfter(limit) && generated < cap) {
      generated++;
      if (!current.isBefore(from)) dates.add(current);
      current = _addDays(current, 7 * interval);
    }
    return dates;
  }

  // Giorni scelti: si cammina giorno per giorno. Con INTERVAL la settimana
  // della **prima** occorrenza è l'ancora: cadono solo i giorni delle settimane
  // 0, N, 2N… dalla prima (inizio settimana lunedì, il default iCal). Senza
  // COUNT il filtro non dipende dal cammino, quindi si può cominciare dalla
  // finestra; con COUNT si parte dalla prima occorrenza.
  //
  // Attenzione al verso della condizione: con `count == null` si parte dal
  // **più avanti** fra prima occorrenza e inizio finestra. Scritto al contrario
  // (com'era) una serie nata anni prima faceva camminare tutto l'archivio a ogni
  // chiamata: misurato, 337 ms per disegnare un mese.
  final begin = count == null ? (first.isAfter(from) ? first : from) : first;
  final anchorMonday = _mondayOf(first);
  var current = begin;
  while (!current.isAfter(limit) && generated < cap) {
    if (rule.weekdays.contains(current.weekday)) {
      final weeksSince = _daysBetween(anchorMonday, _mondayOf(current)) ~/ 7;
      if (interval == 1 || weeksSince % interval == 0) {
        generated++;
        if (!current.isBefore(from)) dates.add(current);
      }
    }
    current = _addDays(current, 1);
  }
  return dates;
}

List<DateTime> _monthly(
  RecurrenceRule rule,
  DateTime first,
  DateTime from,
  DateTime limit,
) {
  final interval = rule.interval;
  final count = rule.count;
  final dates = <DateTime>[];
  final cap = count ?? maxOccurrencesPerExpansion;
  var generated = 0;

  // La griglia dei mesi è ancorata alla **prima** occorrenza: con INTERVAL=3
  // che parte a gennaio cadono gennaio, aprile, luglio, ottobre — anche se la
  // finestra comincia a febbraio. Senza COUNT si aggancia la griglia al primo
  // mese utile; con COUNT si parte dalla prima occorrenza.
  var year = first.year;
  var month = first.month;
  if (count == null) {
    final begin = first.isAfter(from) ? first : from;
    final monthsSince =
        (begin.year - first.year) * 12 + begin.month - first.month;
    final anchor =
        _addMonths(first, (monthsSince + interval - 1) ~/ interval * interval);
    year = anchor.year;
    month = anchor.month;
  }

  while (generated < cap) {
    // Il giorno del mese è quello della data di partenza; se quel mese non lo
    // contiene (31 in un mese da 30, 29 febbraio) l'occorrenza si salta e non
    // consuma il COUNT: non è mai nata.
    if (first.day <= _daysInMonth(year, month)) {
      final candidate = DateTime(year, month, first.day);
      if (candidate.isAfter(limit)) break;
      final isReal = !candidate.isBefore(first);
      if (isReal) generated++;
      if (isReal && !candidate.isBefore(from)) dates.add(candidate);
    } else if (DateTime(year, month, 1).isAfter(limit)) {
      break;
    }

    month += interval;
    while (month > 12) {
      month -= 12;
      year += 1;
    }
  }
  return dates;
}

List<DateTime> _yearly(
  RecurrenceRule rule,
  DateTime first,
  DateTime from,
  DateTime limit,
) {
  final interval = rule.interval;
  final count = rule.count;
  final dates = <DateTime>[];
  final cap = count ?? maxOccurrencesPerExpansion;
  var generated = 0;

  // Come per i mesi: la griglia è ancorata alla prima occorrenza (INTERVAL=2
  // partendo da un anno pari resta sugli anni pari).
  var year = first.year;
  if (count == null) {
    final beginYear = first.isAfter(from) ? first.year : from.year;
    final yearsSince = beginYear - first.year;
    year = first.year + (yearsSince + interval - 1) ~/ interval * interval;
  }

  while (generated < cap) {
    final candidate = DateTime(year, first.month, first.day);
    if (candidate.isAfter(limit)) break;
    // Il 29 febbraio esiste solo negli anni bisestili: negli altri si salta,
    // e il salto non consuma il COUNT (l'occorrenza non è mai nata).
    final isReal = candidate.day == first.day && candidate.month == first.month;
    if (isReal) generated++;
    if (isReal && !candidate.isBefore(first) && !candidate.isBefore(from)) {
      dates.add(candidate);
    }
    year += interval;
  }
  return dates;
}

int _daysInMonth(int year, int month) {
  if (month == 2) {
    final leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    return leap ? 29 : 28;
  }
  // Gennaio…dicembre. (L'array sbagliato che avevo copiato dalla v2 faceva
  // saltare il 31 di ottobre e dicembre: anche lì c'era lo stesso errore.)
  const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return days[month - 1];
}

/// Aritmetica **di calendario**, non di durata.
///
/// `DateTime.add(Duration(days: n))` attraversa l'ora legale e sposta l'ora:
/// dopo un cambio d'ora la data calcolata finisce il giorno prima, e le
/// occorrenze slittano. Sommare ai campi (year, month, day + n) no.
DateTime _addDays(DateTime day, int days) {
  return DateTime(day.year, day.month, day.day + days);
}

/// Somma mesi ai campi del calendario, fermandosi al giorno 1: serve solo
/// l'ancora anno/mese (il giorno dell'occorrenza è sempre quello della prima).
/// Usare il giorno di partenza qui normalizzerebbe il 31 nel mese dopo.
DateTime _addMonths(DateTime day, int months) {
  final total = day.month - 1 + months;
  return DateTime(day.year + total ~/ 12, total % 12 + 1, 1);
}

/// Il lunedì della settimana di `day`: l'ancora delle settimane con INTERVAL.
DateTime _mondayOf(DateTime day) => _addDays(day, 1 - day.weekday);

int _daysBetween(DateTime from, DateTime to) {
  return (to.difference(from).inHours / 24).round();
}

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
