import '../../features/calendar/day_axis.dart';

/// I salti di giorno: la parte di conto, senza interfaccia.
///
/// Sta in un file suo per due motivi. Il primo e' il tetto delle 300 righe di
/// `calendar_page.dart`, che con le tre intestazioni cliccabili stava sfondando.
/// Il secondo, piu' importante: queste regole sbagliano facilmente sugli estremi
/// (il 31 in un mese da 30 giorni, il 29 febbraio, il capodanno) e qui si possono
/// provare **da sole**, senza alzare una schermata.
class CalendarJumps {
  const CalendarJumps._();

  /// [giorni] in avanti (o indietro, con il segno meno).
  ///
  /// Il conto passa da `DateTime`, non da `Duration`: a cavallo dell'ora legale
  /// una giornata dura 23 o 25 ore e una `Duration(days: 1)` salterebbe il giorno.
  static DateTime piuGiorni(DateTime day, int giorni) {
    return DateTime(day.year, day.month, day.day + giorni);
  }

  /// La distanza in giorni fra due date, contata in UTC (l'ora legale non conta).
  static int distanzaInGiorni(DateTime da, DateTime a) {
    return DayAxis.indexOf(a) - DayAxis.indexOf(da);
  }
}
