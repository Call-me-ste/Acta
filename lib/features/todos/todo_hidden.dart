import 'domain/todo.dart';
import 'todo_provider.dart';

/// Il segno **«via dal calendario»**: una cosa sola, in un posto solo.
///
/// Un todo spuntato resta nel calendario (si vede che e' fatto) e se ne va solo
/// quando lo si toglie di proposito, con lo scorrimento a destra. Il segno e' una
/// colonna del todo (`hidden_in_calendar`), quindi viaggia col record e vale su
/// tutti i device: non e' un filtro di vista di questo telefono.
///
/// Sta fuori da `TodoProvider` (che ha gia' coda, cache e stato) come le altre
/// estensioni: si legge come se fosse dentro, e il file del provider resta sotto
/// il tetto di righe. Chi chiama deve importare questo file.
extension TodoHidden on TodoProvider {
  /// Toglie il todo **dal calendario**: la scheda Todo e l'agenda continuano a
  /// mostrarlo. Passa da `updateTodo`, quindi la scrittura e' in transazione con
  /// la sua voce di outbox e il clock avanza (il sync lo porta agli altri device).
  ///
  /// Si rilegge il todo **adesso** dalla lista invece di fidarsi di quello che
  /// ha in mano chi chiama: l'annulla dell'avviso arriva dopo una scrittura, e
  /// partire da una copia vecchia vorrebbe dire due record con lo stesso clock.
  Future<void> hideFromCalendar(Todo todo) => updateTodo(
        _attuale(todo).copyWith(hiddenInCalendar: true),
      );

  /// L'annulla: il todo torna nelle griglie. E' la stessa scrittura al contrario
  /// (una per mettere il segno, una per toglierlo), non due strade diverse.
  Future<void> showInCalendar(Todo todo) => updateTodo(
        _attuale(todo).copyWith(hiddenInCalendar: false),
      );

  /// Il todo **come e' adesso** nella lista, o quello passato se non c'e' piu'
  /// (cancellato nel frattempo: la scrittura e' un update, si perde la riga e
  /// va bene cosi').
  Todo _attuale(Todo todo) =>
      todos.firstWhere((altro) => altro.id == todo.id, orElse: () => todo);
}
