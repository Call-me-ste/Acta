/// Gli estremi effettivi di un evento: con «tutto il giorno» sono le estremità
/// della giornata (00:00 → 23:59), altrimenti gli orari scelti.
///
/// Sta nel dominio e non nel form perché è una regola del dominio: si verifica
/// con date e minuti, senza guardare lo schermo. Il form la chiama e basta.
(DateTime, DateTime) eventBounds({
  required DateTime day,
  DateTime? endDay,
  required int startMinutes,
  required int endMinutes,
  required bool allDay,
}) {
  final lastDay = endDay ?? day;
  if (allDay) {
    return (
      DateTime(day.year, day.month, day.day),
      DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59),
    );
  }
  return (_at(day, startMinutes), _at(lastDay, endMinutes));
}

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
