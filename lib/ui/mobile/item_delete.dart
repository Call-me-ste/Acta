import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/events/domain/event.dart';
import '../../features/events/event_provider.dart';
import '../../features/todos/domain/todo.dart';
import '../../features/todos/todo_provider.dart';
import '../shared/confirm_delete.dart';
import '../shared/undo.dart';

/// Cancella l'elemento che il form sta modificando e lascia **annullare**.
///
/// Sta in un file suo perché è la coppia che va sempre insieme: prima la
/// domanda, poi la cancellazione, poi l'avviso con l'undo. Chi chiama si limita
/// a chiudere il form se la risposta è `true`.
///
/// Il messenger e i provider si prendono **prima** della cancellazione: il form
/// sparisce subito dopo, e il suo `context` non varrebbe più.
/// Cancella l'elemento che il form sta modificando: prende il titolo scritto
/// (per l'avviso) e dice se il form deve chiudersi.
///
/// Sta qui e non nel form per il tetto delle righe: è la stessa cosa che faceva
/// lì, ma si legge da sola.
Future<bool> deleteFromForm(
  BuildContext context, {
  required String title,
  required bool isEvent,
  Event? event,
  Todo? todo,
}) {
  final what =
      title.trim().isEmpty ? (isEvent ? 'evento' : 'To do') : title.trim();
  return deleteItem(context, what: what, event: event, todo: todo);
}

Future<bool> deleteItem(
  BuildContext context, {
  required String what,
  Event? event,
  Todo? todo,
}) async {
  final confirmed = await confirmDelete(context, what);
  if (!confirmed || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);

  if (event != null) {
    final provider = context.read<EventProvider>();
    await provider.deleteEvent(event.id);
    showUndoSnackBarOn(
      messenger,
      message: 'Evento eliminato',
      onUndo: () => provider.restoreEvent(event),
    );
    return true;
  }
  if (todo != null) {
    final provider = context.read<TodoProvider>();
    await provider.deleteTodo(todo.id);
    showUndoSnackBarOn(
      messenger,
      message: 'To do eliminato',
      onUndo: () => provider.restoreTodo(todo),
    );
    return true;
  }
  return false;
}
