import 'package:flutter/material.dart';

import 'event_section.dart';
import 'item_todo_part.dart';
import 'item_type.dart';
import 'todo_section.dart';

/// La parte del form che **distingue** i due tipi: orari per un evento, priorità,
/// scadenza e orari per un todo.
///
/// Sta in un file suo per due motivi: il form ha un tetto di 300 righe
/// (`test/architecture_test.dart`) e questo è il pezzo che si può leggere da solo
/// senza avere in mente il resto del foglio. I valori e le callback sono quelli
/// dello stato del form: qui non si prende nessuna decisione, si sceglie quale
/// delle due sezioni mostrare.
class ItemTypeSection extends StatelessWidget {
  const ItemTypeSection({
    super.key,
    required this.type,
    required this.day,
    required this.endDay,
    required this.allDay,
    required this.start,
    required this.end,
    required this.onPickDay,
    required this.onPickEndDay,
    required this.onToggleAllDay,
    required this.onPickStart,
    required this.onPickEnd,
    required this.todo,
    required this.onTodo,
  });

  // Parte evento.
  final ItemType type;
  final DateTime day;
  final DateTime endDay;
  final bool allDay;
  final TimeOfDay start;
  final TimeOfDay end;
  final VoidCallback onPickDay;
  final VoidCallback onPickEndDay;
  final ValueChanged<bool> onToggleAllDay;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  /// La parte todo, tutta insieme (priorità, scadenza, orari): la regola degli
  /// orari sta in `ParteTodo`, non qui.
  final ParteTodo todo;
  final ValueChanged<ParteTodo> onTodo;

  @override
  Widget build(BuildContext context) {
    if (type == ItemType.evento) {
      return EventSection(
        day: day,
        endDay: endDay,
        allDay: allDay,
        start: start,
        end: end,
        onPickDay: onPickDay,
        onPickEndDay: onPickEndDay,
        onToggleAllDay: onToggleAllDay,
        onPickStart: onPickStart,
        onPickEnd: onPickEnd,
      );
    }
    return TodoSection(todo: todo, onTodo: onTodo);
  }
}
