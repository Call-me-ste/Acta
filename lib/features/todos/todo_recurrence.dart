import 'package:uuid/uuid.dart';

import '../../core/database/occurrence_commands.dart';
import '../../core/database/occurrence_store.dart';
import 'domain/todo_dates.dart';
import '../recurrence/domain/recurrence_expansion.dart';
import '../recurrence/domain/recurrence_rule.dart';
import 'domain/todo.dart';
import 'todo_provider.dart';

/// Quanto in la' si cerca la prossima occorrenza: un anno copre anche le regole
/// mensili e annuali senza regalare un ciclo lunghissimo.
const Duration _orizzonte = Duration(days: 366);

/// La **prossima occorrenza** di un todo che ricorre, e se una data occorrenza
/// e' gia' stata segnata fatta.
///
/// Sta fuori da `TodoProvider` (come le finestre del calendario) per il budget
/// di righe del file: si legge come se fosse dentro, ma il provider resta
/// leggibile. Chi chiama deve importare questo file.
extension TodoRecurrence on TodoProvider {
  /// La prossima occorrenza di un todo ricorrente, o `null` se non ricorre o la
  /// serie è finita (`until` passato).
  ///
  /// La riga mostra **questa** data: così un todo che ricorre compare una volta
  /// sola, nel giorno in cui va fatto.
  DateTime? nextOccurrence(Todo todo, {DateTime? from}) {
    // Con `from` esplicito (i test, il calendario) si calcola: la memoria vale
    // per la domanda "da adesso in poi", che e' quella della scheda.
    if (from == null && prossime.containsKey(todo.id)) {
      return prossime[todo.id];
    }

    final rule = RecurrenceRule.tryParse(todo.recurrenceRule);
    final anchor = todo.dueDate;
    final prossima = (rule == null || anchor == null)
        ? null
        : _prossimaOccorrenza(rule, anchor, from ?? DateTime.now());

    if (from == null) prossime[todo.id] = prossima;
    return prossima;
  }

  DateTime? _prossimaOccorrenza(
      RecurrenceRule rule, DateTime anchor, DateTime from) {
    final today = dayOnly(from);
    final days = expandOccurrences(
      rule,
      start: anchor,
      rangeStart: today,
      rangeEnd: today.add(_orizzonte),
    );
    return days.isEmpty ? null : days.first;
  }

  bool isOccurrenceDone(String todoId, DateTime day) {
    final done = doneDays ??= database.occurrences.doneDaysByItem();
    return (done[todoId] ?? const <int>{}).contains(
      OccurrenceStore.dayMillis(day),
    );
  }

  /// Vero se il todo e' **fatto in quel giorno**: per un ricorrente e'
  /// l'occorrenza di quel giorno, per uno singolo e' il todo.
  ///
  /// Sta qui perche' e' l'unico posto che sa la differenza fra i due: le tre
  /// viste del calendario chiedono «fatto?» e non ricostruiscono la regola a
  /// mano (era il modo per dimenticarla in una vista su tre).
  bool isDoneOn(Todo todo, DateTime day) => todo.recurrenceRule.isEmpty
      ? todo.completed
      : isOccurrenceDone(todo.id, day);

  /// Spunta o toglie la spunta a un todo singolo.
  ///
  /// Sta qui dal 18/09 col resto della ricorrenza: la usava solo questo percorso e
  /// la riga dell'elenco, e il file del provider ha un tetto di righe.
  Future<void> toggleTodo(String id) async {
    final indice = todos.indexWhere((todo) => todo.id == id);
    if (indice < 0) return;

    await updateTodo(
        todos[indice].copyWith(completed: !todos[indice].completed));
  }

  /// Spunta un todo per un giorno: un ricorrente segna **solo** quell'occorrenza
  /// (la serie resta), uno singolo cambia stato. Una regola sola per tutti i
  /// punti del calendario che spuntano un todo (striscia del giorno, sezione del
  /// mese, scheda Todo).
  ///
  /// Sta qui e non nel provider dal 18/09: e' logica di ricorrenza, e il file del
  /// provider ha un tetto di righe che va rispettato.
  void toggleForDay(Todo todo, DateTime day) {
    if (todo.recurrenceRule.isNotEmpty) {
      completeOccurrence(todo.id, day);
    } else {
      toggleTodo(todo.id);
    }
  }

  /// Segna **una** occorrenza come fatta. La serie resta intatta: e' la
  /// differenza fra "l'ho fatto oggi" e "non lo faccio piu'.
  ///
  /// La scrittura sta nel layer database perche' e' la stessa che serve agli
  /// eventi: una sola implementazione della conferma.
  Future<void> completeOccurrence(String todoId, DateTime day) async {
    database.markOccurrenceDone(
      itemId: todoId,
      day: day,
      operationId: const Uuid().v4(),
    );
    // La cache si aggiorna in loco: la conferma appena scritta e' gia' qui.
    (doneDays ??= {})[todoId] = {
      ...(doneDays?[todoId] ?? const <int>{}),
      OccurrenceStore.dayMillis(day),
    };
    // Le finestre invece no: quello che e' fatto cambia cosa si vede nelle griglie.
    dopoScritturaEsterna();
  }
}
