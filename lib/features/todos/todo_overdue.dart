import '../overdue/domain/overdue_item.dart';
import '../recurrence/domain/recurrence_expansion.dart';
import '../recurrence/domain/recurrence_rule.dart';
import 'todo_provider.dart';
import 'todo_recurrence.dart';

/// Gli scaduti da confermare, e come si confermano.
///
/// Sta fuori da `TodoProvider` — che ha già coda, ricorrenza, cache e stato —
/// ma si legge come se fosse dentro: un'**estensione** e non una classe a parte,
/// perché ha bisogno esattamente dello stato del provider, e solo di quello
/// pubblico. Chi chiama deve importare questo file (il compilatore lo dice).
extension TodoOverdue on TodoProvider {
  /// Gli elementi scaduti e non confermati: i todo singoli con la scadenza
  /// prima di oggi (a qualunque età) e le occorrenze passate dei ricorrenti
  /// dentro la finestra — di un ricorrente senza finestra tornerebbe indietro
  /// tutta la storia della serie.
  List<OverdueItem> overdue(int days, {required DateTime until}) {
    final today = _dayOnly(until);
    final windowStart = DateTime(today.year, today.month, today.day - days);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final items = <OverdueItem>[];

    for (final todo in todos) {
      final due = todo.dueDate;
      if (due == null) continue;

      final rule = RecurrenceRule.tryParse(todo.recurrenceRule);
      if (rule == null) {
        if (todo.completed || !_dayOnly(due).isBefore(today)) continue;
        items.add(
          OverdueItem(
            id: todo.id,
            title: todo.title,
            date: _dayOnly(due),
            isEvent: false,
          ),
        );
        continue;
      }

      for (final day in expandOccurrences(
        rule,
        start: due,
        rangeStart: windowStart,
        rangeEnd: yesterday,
      )) {
        if (isOccurrenceDone(todo.id, day)) continue;
        items.add(
          OverdueItem(
            id: todo.id,
            title: todo.title,
            date: day,
            isEvent: false,
          ),
        );
      }
    }
    return items;
  }

  /// Conferma un elemento scaduto: un todo singolo diventa completo, un
  /// ricorrente segna **quella** occorrenza (la serie resta).
  void confirmOverdue(String todoId, DateTime day) {
    final index = todos.indexWhere((todo) => todo.id == todoId);
    if (index < 0) return;
    final todo = todos[index];
    if (todo.recurrenceRule.isEmpty) {
      if (!todo.completed) updateTodo(todo.copyWith(completed: true));
      return;
    }
    completeOccurrence(todo.id, day);
  }
}

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
