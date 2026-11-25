import '../../features/todos/domain/todo.dart';
import '../shared/date_math.dart';

/// La parte **todo** del form, in un posto solo: priorità, scadenza e orari.
///
/// Perché un oggetto e non quattro campi sparsi nello stato del form: qui vive
/// **la regola** degli orari — esistono solo con una scadenza, e togliendo la
/// scadenza se ne vanno con lei — e una regola scritta in un posto solo non può
/// essere dimenticata in un percorso di salvataggio. Il form ha anche un tetto
/// di righe (`test/architecture_test.dart`), e questo lo aiuta.
class ParteTodo {
  const ParteTodo({
    this.priority = 0,
    this.dueDate,
    this.startMinutes,
    this.endMinutes,
  });

  /// I valori di partenza per un todo nuovo (dal giorno da cui si è aperto il
  /// form) o per uno che si sta modificando.
  factory ParteTodo.da(Todo? todo, {required DateTime giorno}) => todo == null
      ? ParteTodo(dueDate: dateOnly(giorno))
      : ParteTodo(
          priority: todo.priority,
          dueDate: todo.dueDate,
          startMinutes: todo.startMinutes,
          endMinutes: todo.endMinutes,
        );

  final int priority;
  final DateTime? dueDate;

  /// Minuti dalla mezzanotte, nulli = solo data.
  final int? startMinutes;
  final int? endMinutes;

  /// Vero quando c'è qualcosa da togliere: è quello che decide se mostrare
  /// «Rimuovi orario».
  bool get conOrario => startMinutes != null || endMinutes != null;

  ParteTodo copyWith({int? priority}) =>
      ParteTodo(
        priority: priority ?? this.priority,
        dueDate: dueDate,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
      );

  /// Cambia (o toglie) la scadenza. **Togliendola si azzerano gli orari**: un
  /// orario senza giorno non vuol dire niente.
  ParteTodo conScadenza(DateTime? nuova) => nuova == null
      ? ParteTodo(priority: priority)
      : ParteTodo(
          priority: priority,
          dueDate: nuova,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
        );

  /// I due orari nuovi: `(null, null)` torna al solo giorno, con la scadenza
  /// che resta.
  ParteTodo conOrari(int? start, int? end) => ParteTodo(
        priority: priority,
        dueDate: dueDate,
        startMinutes: start,
        endMinutes: end,
      );
}
