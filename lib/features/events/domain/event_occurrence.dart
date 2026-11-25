import 'event.dart';

/// Un evento **in un giorno preciso**: è quello che una vista mostra.
///
/// Per un evento senza ricorrenza è l'evento stesso; per uno ricorrente è
/// l'evento con inizio e fine spostati sulla data dell'occorrenza, mentre l'ora
/// e la durata restano quelle del template.
///
/// `date` è il campo su cui ogni vista raggruppa e ordina: **mai** la data del
/// template e mai la regola. È la regola che impedisce a un evento ricorrente di
/// comparire in ogni sezione (il bug della v2): un'occorrenza è
/// `(evento, data)` e appartiene a un giorno solo.
class EventOccurrence {
  const EventOccurrence({
    required this.event,
    required this.date,
    required this.start,
    required this.end,
  });

  final Event event;

  /// Il giorno dell'occorrenza, a mezzanotte.
  final DateTime date;

  final DateTime start;
  final DateTime end;

  bool get isRecurring => event.recurrenceRule.isNotEmpty;
  String get title => event.title;
  int get colorIndex => event.colorIndex;
}
