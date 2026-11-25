/// La regola di ricorrenza di un item.
///
/// Si serializza nella colonna `recurrence_rule` con un **sottoinsieme** di
/// RRULE iCal — `FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;UNTIL=2026-12-31` — perché
/// così la stringa è leggibile, portabile e non richiede un parser completo.
/// `INTERVAL` ("ogni 2 settimane") e `COUNT` ("per N volte") sono supportati:
/// aggiunti senza cambiare lo schema, come previsto al momento del subset.
library;

enum RecurrenceFrequency {
  daily('DAILY'),
  weekly('WEEKLY'),
  monthly('MONTHLY'),
  yearly('YEARLY');

  const RecurrenceFrequency(this.token);
  final String token;

  static RecurrenceFrequency? fromToken(String token) {
    for (final frequency in values) {
      if (frequency.token == token) return frequency;
    }
    return null;
  }
}

/// Giorni della settimana come li usa iCal: 1 = lunedì … 7 = domenica.
class Weekdays {
  const Weekdays._();

  static const Map<int, String> tokens = {
    1: 'MO',
    2: 'TU',
    3: 'WE',
    4: 'TH',
    5: 'FR',
    6: 'SA',
    7: 'SU',
  };

  static const Set<int> mondayToFriday = {1, 2, 3, 4, 5};

  static String token(int weekday) => tokens[weekday] ?? '';

  static int? fromToken(String token) {
    for (final entry in tokens.entries) {
      if (entry.value == token.toUpperCase()) return entry.key;
    }
    return null;
  }
}

class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.weekdays = const {},
    this.until,
    this.interval = 1,
    this.count,
  });

  final RecurrenceFrequency frequency;

  /// 1 = lunedì … 7 = domenica. Vuoto significa "lo stesso giorno della data di
  /// partenza": è il senso di "ogni settimana" senza altri dettagli.
  final Set<int> weekdays;

  /// Ultimo giorno valido, incluso. `null` = senza fine.
  final DateTime? until;

  /// Ogni quante unità della frequenza ricorre: 3 con `FREQ=DAILY` = "ogni 3
  /// giorni". 1 = ogni volta: è il default e non viene serializzato.
  final int interval;

  /// Quante occorrenze in tutto, contate **dalla prima** della serie (semantica
  /// iCal). `null` = senza limite.
  final int? count;

  /// `null` quando la stringa è vuota o non riconosciuta: un dato remoto
  /// illeggibile diventa "nessuna ricorrenza", non un'eccezione che blocca
  /// l'apertura di una lista.
  static RecurrenceRule? tryParse(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;

    RecurrenceFrequency? frequency;
    var weekdays = <int>{};
    DateTime? until;
    var interval = 1;
    int? count;

    for (final part in text.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      final key = part.substring(0, separator).toUpperCase();
      final value = part.substring(separator + 1);

      switch (key) {
        case 'FREQ':
          frequency = RecurrenceFrequency.fromToken(value.toUpperCase());
        case 'BYDAY':
          weekdays = value
              .split(',')
              .map((token) => Weekdays.fromToken(token.trim()))
              .whereType<int>()
              .toSet();
        case 'UNTIL':
          until = _parseDate(value);
        case 'INTERVAL':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed >= 1) interval = parsed;
        case 'COUNT':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed >= 1) count = parsed;
      }
    }

    if (frequency == null) return null;
    return RecurrenceRule(
      frequency: frequency,
      weekdays: weekdays,
      until: until,
      interval: interval,
      count: count,
    );
  }

  String toRuleString() {
    final parts = <String>['FREQ=${frequency.token}'];
    if (weekdays.isNotEmpty) {
      final sorted = weekdays.toList()..sort();
      parts.add('BYDAY=${sorted.map(Weekdays.token).join(',')}');
    }
    // Il default (1) non si serializza: le regole senza intervallo producono
    // la stessa stringa di prima.
    if (interval > 1) parts.add('INTERVAL=$interval');
    final limit = until;
    if (limit != null) parts.add('UNTIL=${_formatDate(limit)}');
    final total = count;
    if (total != null) parts.add('COUNT=$total');
    return parts.join(';');
  }

  /// Una regola serve solo se ha almeno un giorno su cui cadere.
  bool get isActive => true;

  static DateTime? _parseDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
