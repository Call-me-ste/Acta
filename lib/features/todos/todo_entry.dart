import '../recurrence/domain/recurrence_rule.dart';
import 'domain/todo.dart';
import 'todo_provider.dart';
import 'todo_recurrence.dart';

/// Un todo come lo vede la scheda: il todo, la sua **prossima occorrenza** (se
/// ricorre) e se e' fatto.
///
/// Si calcola una volta sola per todo: prima lo facevano la sezione, il filtro e
/// la riga, ognuno per conto suo — e per un ricorrente "e' fatto?" costa una
/// query sulle occorrenze.
class TodoEntry {
  const TodoEntry({required this.todo, required this.next, required this.done});

  factory TodoEntry.of(Todo todo, TodoProvider provider) {
    final rule = RecurrenceRule.tryParse(todo.recurrenceRule);
    // La riga mostra la prossima occorrenza: cosi' un todo che ricorre compare
    // una volta sola, nel giorno in cui va fatto.
    final next = rule == null ? null : provider.nextOccurrence(todo);
    return TodoEntry(
      todo: todo,
      next: next,
      done: next != null
          ? provider.isOccurrenceDone(todo.id, next)
          : todo.completed,
    );
  }

  final Todo todo;

  /// La prossima occorrenza di un ricorrente, `null` per gli altri.
  final DateTime? next;

  /// Fatto: per un ricorrente e' **quella** occorrenza, per gli altri il todo.
  final bool done;

  /// La data che la riga deve mostrare (l'occorrenza per un ricorrente).
  DateTime? get due => next ?? todo.dueDate;
}
