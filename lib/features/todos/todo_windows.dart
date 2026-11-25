import 'domain/todo.dart';
import 'domain/todo_dates.dart';
import '../filters/filtro_condiviso.dart';
import '../recurrence/domain/recurrence_expansion.dart';
import '../recurrence/domain/recurrence_rule.dart';
import 'todo_provider.dart';

/// I todo **giorno per giorno** dentro una finestra: sono le query che servono
/// al calendario (mese, settimana, giorno).
///
/// Che cosa entra: tutto quello che il giorno ha da mostrare — **anche i todo
/// fatti**, che restano visibili e barrati finche' non li si toglie dal
/// calendario con lo scorrimento a destra. Fuori restano solo quelli col segno
/// `hidden_in_calendar`.
///
/// Sta fuori da `TodoProvider` — che ha già coda, coda di scrittura, cache e
/// stato — come estensione: si legge come se fosse dentro, ma il provider
/// rispetta il budget di righe (`test/architecture_test.dart`). Chi chiama deve
/// importare questo file (il compilatore lo dice).
extension TodoWindows on TodoProvider {
  /// I todo da mostrare **giorno per giorno** dentro la finestra `[from, to]`
  /// (estremi inclusi).
  ///
  /// Un giro solo su tutti i todo: una `RecurrenceRule.tryParse` per todo e
  /// un'espansione per l'intera finestra. Prima la griglia del mese chiedeva
  /// `todosForDate` per ~45 giorni, e **ogni** chiamata ri-analizzava la regola
  /// di **ogni** todo: lo stesso lavoro 45 volte. È la regola di ricorrenza che
  /// si paga di più, ed è quella che qui si fa una volta sola.
  Map<DateTime, List<Todo>> todosByDay(DateTime from, DateTime to) {
    final start = dayOnly(from);
    final end = dayOnly(to);
    final key = (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
    final cached = windows[key];
    if (cached != null) return cached;

    final byDay = <DateTime, List<Todo>>{};
    for (final todo in todos) {
      // Il segno «via dal calendario» e' l'unica cosa che toglie un todo dalle
      // griglie: la spunta no (si vede che e' fatto, e resta li').
      if (todo.hiddenInCalendar) continue;
      final due = todo.dueDate;
      if (due == null) continue;

      final rule = RecurrenceRule.tryParse(todo.recurrenceRule);
      if (rule == null) {
        final day = dayOnly(due);
        if (day.isBefore(start) || day.isAfter(end)) continue;
        (byDay[day] ??= []).add(todo);
        continue;
      }

      // Un ricorrente non guarda `completed`: la serie resta, a cambiare e' la
      // singola occorrenza (una riga per data in `occurrence_overrides`) — e
      // anche un'occorrenza fatta si mostra, con la sua spunta.
      for (final day in expandOccurrences(
        rule,
        start: due,
        rangeStart: start,
        rangeEnd: end,
      )) {
        (byDay[day] ??= []).add(todo);
      }
    }

    if (windows.length >= TodoProvider.maxWindows) {
      windows.remove(windows.keys.first);
    }
    windows[key] = byDay;
    return byDay;
  }

  /// I todo di una finestra **per giorno e filtrati**: e' quello che chiedono le
  /// viste del calendario (mese e settimana), che devono sapere cosa mostrare
  /// giorno per giorno senza rileggere il database e senza dimenticare il filtro.
  Map<DateTime, List<Todo>> todoDelCalendario(
    DateTime from,
    DateTime to,
    FiltroCondiviso filtro,
  ) =>
      {
        for (final voce in todosByDay(from, to).entries)
          voce.key: filtro.filtraTodo(voce.value),
      };

  /// I todo di un giorno: quelli singoli con quella scadenza, più le occorrenze
  /// dei ricorrenti che cadono lì. Fatti compresi (il fatto si vede dalla
  /// spunta), esclusi quelli col segno «via dal calendario».
  /// Sta qui e non nella UI perché serve sia alla vista giornaliera sia ai
  /// puntini del mese, e la regola è una sola.
  List<Todo> todosForDate(DateTime day) {
    final target = dayOnly(day);
    return todosByDay(target, target)[target] ?? const <Todo>[];
  }
}
