/// La scala dei giorni: da una **data** a un **indice intero** e ritorno.
///
/// Serve alla `PageView` della vista giorno, che vuole numeri interi, e al salto
/// di settimana. Sta qui e non nel widget perche' e' aritmetica di date, e perche'
/// il file della pagina ha un tetto di 300 righe.
class DayAxis {
  const DayAxis._();

  /// Quanti giorni disegna la vista settimana: **sette**, la settimana mostrata.
  ///
  /// Ci era stato messo il doppio (la settimana più la successiva) per far
  /// entrare sempre il giorno scelto nella prima colonna a sinistra. Sbagliato:
  /// l'utente ha visto «due settimane invece che una», e aveva ragione — sotto
  /// l'intestazione «14 - 20 set» comparivano i giorni 21, 22, 23. L'asse è
  /// tornato a sette e il giorno scelto resta **visibile per intero**, andando a
  /// sinistra quando c'è posto (vedi il riallineamento in `week_view.dart`).
  ///
  /// Sta qui e non dentro la vista perché lo stesso numero serve al precarico
  /// (`calendar_warmup.dart`), che deve chiedere **la stessa** finestra:
  /// altrimenti il primo cambio vista rilegge il database.
  static const int giorniAsseSettimana = 7;

  /// L'origine della scala: un giorno qualunque, l'inizio del calendario.
  static final DateTime origine = DateTime(2020, 1, 1);

  /// La distanza in giorni, contata in **UTC**: con l'ora legale una giornata
  /// dura 23 o 25 ore e `difference().inDays` sbaglierebbe di uno.
  static int indexOf(DateTime day) {
    return DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(origine.year, origine.month, origine.day))
        .inDays;
  }

  /// Il contrario di [indexOf], sommando ai campi del calendario (non ai
  /// millisecondi): è l'unica aritmetica corretta per le date.
  static DateTime dayAt(int index) =>
      DateTime(origine.year, origine.month, origine.day + index);

  /// Il lunedì della settimana di `day`.
  static DateTime mondayOf(DateTime day) =>
      DateTime(day.year, day.month, day.day + 1 - day.weekday);
}
