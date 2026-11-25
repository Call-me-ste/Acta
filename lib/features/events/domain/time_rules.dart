import 'dart:math' as math;

/// Le regole dei **campi orari incompleti** di un evento, in minuti dalla
/// mezzanotte: nessun widget, nessun `TimeOfDay`, così si verificano con numeri
/// invece che con un dito su un quadrante.
///
/// Le tre regole, e il perché:
///
/// * chi scrive «dalle 21» intende **un'ora**, se non dice altro: cambiando
///   l'inizio, se la fine non gli sta più dietro diventa inizio + 1 ora;
/// * vale al contrario per la fine: cambiandola, l'inizio diventa fine − 1 ora;
/// * la giornata è un limite: una fine calcolata oltre le 23:59 si ferma lì e un
///   inizio sotto le 00:00 si ferma lì. Un evento che passa la mezzanotte si
///   crea come due eventi (o tutto il giorno) invece di scavalcare il giorno per
///   sbaglio.
class EventTimeRules {
  const EventTimeRules._();

  /// La durata che si assume quando non c'è altro: un'ora.
  static const int defaultDurationMinutes = 60;

  static const int lastMinuteOfDay = 23 * 60 + 59;

  /// La fine da usare dopo aver cambiato l'inizio: quella scelta se sta ancora
  /// dietro, altrimenti l'inizio più un'ora.
  static int endFor({
    required int startMinutes,
    required int currentEndMinutes,
  }) {
    if (currentEndMinutes > startMinutes) return currentEndMinutes;
    return math.min(startMinutes + defaultDurationMinutes, lastMinuteOfDay);
  }

  /// L'inizio da usare dopo aver cambiato la fine: quello scelto se sta ancora
  /// davanti, altrimenti la fine meno un'ora.
  static int startFor({
    required int endMinutes,
    required int currentStartMinutes,
  }) {
    if (currentStartMinutes < endMinutes) return currentStartMinutes;
    return math.max(endMinutes - defaultDurationMinutes, 0);
  }

  static int durationMinutes({
    required int startMinutes,
    required int endMinutes,
  }) {
    return math.max(endMinutes - startMinutes, 0);
  }

  /// «45 min», «1 h», «1 h 30 min»: come lo direbbe una persona.
  static String durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }
}
