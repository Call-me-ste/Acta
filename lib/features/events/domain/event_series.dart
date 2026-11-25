import '../../recurrence/domain/recurrence_expansion.dart';
import '../../recurrence/domain/recurrence_rule.dart';
import 'event.dart';
import 'event_occurrence.dart';

/// Tutte le occorrenze che cadono in `[from, to)`: gli eventi **singoli** che ci
/// stanno dentro piu' le occorrenze dei **ricorrenti** espanse nella finestra.
///
/// Sta qui e non dentro `EventProvider` perche' la chiedono due lettori diversi:
/// la griglia del calendario (che le disegna, con la sua cache) e il pianificatore
/// dei promemoria (che ci mette le notifiche, una volta sola all'avvio).
/// Duplicarla vorrebbe dire due espansioni che possono divergere — e un promemoria
/// su un'occorrenza che il calendario non mostra.
List<EventOccurrence> occurrencesInWindow({
  required DateTime from,
  required DateTime to,
  required Iterable<Event> singoli,
  required Iterable<Event> ricorrenti,
}) {
  final occurrences = <EventOccurrence>[
    for (final event in singoli)
      EventOccurrence(
        event: event,
        date: _dayOnly(event.start),
        start: event.start,
        end: event.end,
      ),
    for (final event in ricorrenti)
      ...occurrencesOfEvent(event, from: from, to: to),
  ];
  occurrences.sort((a, b) => a.start.compareTo(b.start));
  return occurrences;
}

/// Le occorrenze di **una** serie dentro la finestra `[from, to)`.
///
/// Sta qui, e non dentro il provider, perché è la parte che costa: la regola si
/// analizza e si espande a ogni lettura, ed è il lavoro che una vista paga mentre
/// si disegna. Essendo una funzione pura (evento + date) si prova con le date,
/// senza database e senza widget.
///
/// L'ora e la durata restano quelle del template: cambia solo la data — è questo
/// che impedisce a un ricorrente di comparire come sé stesso invece che come
/// occorrenza.
List<EventOccurrence> occurrencesOfEvent(
  Event event, {
  required DateTime from,
  required DateTime to,
}) {
  final rule = RecurrenceRule.tryParse(event.recurrenceRule);

  if (rule == null) {
    // Regola illeggibile: meglio mostrare l'evento come singolo che farlo
    // sparire da ogni vista.
    if (event.start.isBefore(from) || !event.start.isBefore(to)) {
      return const [];
    }
    return [
      EventOccurrence(
        event: event,
        date: _dayOnly(event.start),
        start: event.start,
        end: event.end,
      ),
    ];
  }

  final duration = event.end.difference(event.start);
  final lastMoment = to.subtract(const Duration(milliseconds: 1));

  return [
    for (final day in expandOccurrences(
      rule,
      start: event.start,
      rangeStart: from,
      rangeEnd: lastMoment,
    ))
      EventOccurrence(
        event: event,
        date: day,
        start: DateTime(
          day.year,
          day.month,
          day.day,
          event.start.hour,
          event.start.minute,
        ),
        end: DateTime(
          day.year,
          day.month,
          day.day,
          event.start.hour,
          event.start.minute,
        ).add(duration),
      ),
  ];
}

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
