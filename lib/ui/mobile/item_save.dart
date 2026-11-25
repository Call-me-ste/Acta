import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/events/domain/event.dart';
import '../../features/events/domain/event_bounds.dart';
import '../../features/events/event_provider.dart';
import '../../features/todos/domain/todo.dart';
import '../../features/todos/todo_provider.dart';

/// I valori del form raccolti: è la materia prima del salvataggio, senza widget
/// dentro.
class ItemDraft {
  const ItemDraft({
    required this.isEvent,
    required this.title,
    required this.day,
    this.endDay,
    this.keepEventBounds = false,
    required this.startMinutes,
    required this.endMinutes,
    required this.allDay,
    required this.priority,
    required this.dueDate,
    required this.colorIndex,
    required this.colorHex,
    required this.recurrenceRule,
    this.categoryIds = const [],
    this.location = '',
    this.note = '',
    this.todoStartMinutes,
    this.todoEndMinutes,
    this.reminderLeads,
    this.reminderSound,
  });

  final bool isEvent;
  final String title;
  final DateTime day;
  final DateTime? endDay;
  final bool keepEventBounds;
  final int startMinutes;
  final int endMinutes;
  final bool allDay;
  final int priority;
  final DateTime? dueDate;
  final int? colorIndex;
  final String? colorHex;
  final String recurrenceRule;

  /// Le categorie scelte (da 1 a 3): il limite lo impone il codec degli id, che
  /// vale anche per un record arrivato da un altro dispositivo.
  final List<String> categoryIds;

  /// Dove succede. Testo libero: i suggerimenti sono i posti già usati.
  final String location;

  /// Nota libera dell'elemento.
  final String note;

  /// Gli anticipi del promemoria: `null` = default delle impostazioni, elenco
  /// vuoto = nessuno, altrimenti i minuti di anticipo (uno o più).
  final List<int>? reminderLeads;

  /// Il suono del promemoria: `null` = eredita l'impostazione.
  final bool? reminderSound;

  /// Gli orari del **todo**, in minuti dalla mezzanotte: nulli = solo data.
  ///
  /// Stanno separati da `startMinutes`/`endMinutes`, che sono quelli degli
  /// eventi: li' non possono mancare, perche' un evento e' sempre un intervallo.
  final int? todoStartMinutes;
  final int? todoEndMinutes;
}

/// Salva quello che c'è nel form.
///
/// Torna il **messaggio d'errore** da mostrare, o `null` se è andata: la
/// validazione sta qui in un posto solo invece che sparsa nel form, ed è la
/// parte lunga che si può leggere senza guardare lo schermo.
Future<String?> saveItem(
  BuildContext context,
  ItemDraft draft, {
  Event? event,
  Todo? todo,
}) async {
  if (draft.isEvent) {
    final (start, end) = draft.keepEventBounds && event != null
        ? (event.start, event.end)
        : eventBounds(
            day: draft.day,
            endDay: draft.endDay,
            startMinutes: draft.startMinutes,
            endMinutes: draft.endMinutes,
            allDay: draft.allDay,
          );
    if (!end.isAfter(start)) {
      return 'La fine deve venire dopo l’inizio';
    }

    final provider = context.read<EventProvider>();
    if (event == null) {
      await provider.addEvent(
        title: draft.title,
        start: start,
        end: end,
        colorIndex: draft.colorIndex ?? 0,
        colorHex: draft.colorHex,
        recurrenceRule: draft.recurrenceRule,
        allDay: draft.allDay,
        categoryIds: draft.categoryIds,
        location: draft.location,
        note: draft.note,
        reminderLeads: draft.reminderLeads,
        reminderSound: draft.reminderSound,
      );
      return null;
    }
    await provider.updateEvent(
      Event(
        id: event.id,
        title: draft.title,
        description: event.description,
        start: start,
        end: end,
        allDay: draft.allDay,
        colorIndex: draft.colorIndex ?? 0,
        colorHex: draft.colorHex,
        recurrenceRule: draft.recurrenceRule,
        categoryIds: draft.categoryIds,
        location: draft.location,
        note: draft.note,
        reminderLeads: draft.reminderLeads,
        reminderSound: draft.reminderSound,
        version: event.version,
        updatedAt: event.updatedAt,
      ),
    );
    return null;
  }

  // Una serie ha bisogno di un giorno da cui partire.
  if (draft.recurrenceRule.isNotEmpty && draft.dueDate == null) {
    return 'Serve una scadenza per far partire la ricorrenza';
  }

  // Un orario senza giorno non vuol dire niente: la regola sta **qui**, in un
  // posto solo, cosi' nessun percorso di salvataggio puo' scriverne uno.
  final inizio = draft.dueDate == null ? null : draft.todoStartMinutes;
  final fine = draft.dueDate == null ? null : draft.todoEndMinutes;

  final provider = context.read<TodoProvider>();
  if (todo == null) {
    await provider.addTodo(
      title: draft.title,
      priority: draft.priority,
      dueDate: draft.dueDate,
      startMinutes: inizio,
      endMinutes: fine,
      categoryIds: draft.categoryIds,
      colorIndex: draft.colorIndex,
      recurrenceRule: draft.recurrenceRule,
      location: draft.location,
      note: draft.note,
      reminderLeads: draft.reminderLeads,
      reminderSound: draft.reminderSound,
    );
    return null;
  }
  await provider.updateTodo(
    todo.copyWith(
      title: draft.title,
      priority: draft.priority,
      dueDate: draft.dueDate,
      startMinutes: inizio,
      endMinutes: fine,
      categoryIds: draft.categoryIds,
      colorIndex: draft.colorIndex,
      recurrenceRule: draft.recurrenceRule,
      location: draft.location,
      note: draft.note,
      reminderLeads: draft.reminderLeads,
      reminderSound: draft.reminderSound,
    ),
  );
  return null;
}
