import '../../features/todos/domain/todo_dates.dart';
import 'formatters.dart';

/// Come si legge una scadenza: "Oggi", "Domani", "Scaduta da 3 giorni", o la
/// data quando e' lontana.
///
/// Il numero di giorni c'e' perche' e' quello che serve per capire l'urgenza
/// senza fare il conto a mente: "scaduta" e "scaduta da tre giorni" si
/// affrontano in modo diverso.
///
/// Il conto dei giorni e `isOverdue` vivono nel dominio
/// (`features/todos/domain/todo_dates.dart`) e si ri-esportano da qui, cosi' chi
/// legge una scadenza non deve sapere dove sta la matematica.
export '../../features/todos/domain/todo_dates.dart'
    show daysUntilDue, isOverdue;

String dueLabel(DateTime due, {DateTime? from}) {
  final giorni = daysUntilDue(due, from: from);
  if (giorni == 0) return 'Oggi';
  if (giorni == 1) return 'Domani';
  if (giorni == -1) return 'Scaduta da 1 giorno';
  if (giorni < 0) return 'Scaduta da ${-giorni} giorni';
  if (giorni <= 7) return 'Tra $giorni giorni';
  return formatDay(due);
}
