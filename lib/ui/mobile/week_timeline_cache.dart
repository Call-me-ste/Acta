import 'package:flutter/widgets.dart';

import '../../features/events/domain/event_occurrence.dart';
import '../../features/todos/domain/todo.dart';
import 'week_timeline.dart';

/// La memoria della griglia della settimana: **la stessa istanza** finché i dati e
/// la settimana non cambiano.
///
/// Perché sta in un file suo e non dentro `_WeekViewState`: per il tetto delle 300
/// righe, e perché è una cosa sola — ricordare, non disegnare. Le misure che la
/// giustificano: senza questa memoria, cambiare giorno ricostruiva le 168 celle
/// della griglia e le corsie di tutti gli eventi **dentro** il fotogramma
/// dell'animazione, 20 ms di lavoro Dart sul telefono.
///
/// Restituire la stessa istanza è ciò che fa saltare a Flutter la ricostruzione: il
/// `Stack` sopra la griglia può ricostruirsi quanto vuole (tinta del giorno scelto,
/// intestazioni), la griglia no.
class WeekTimelineCache {
  Widget? _timeline;
  Object? _chiave;

  Widget costruisci({
    required List<DateTime> giorni,
    required double larghezza,
    required List<EventOccurrence> occurrences,
    required Object chiaveTodo,
    Map<DateTime, List<Todo>> todosByDay = const {},
    bool Function(Todo todo, DateTime day)? isDone,
    void Function(Todo todo, DateTime day)? onTodo,
    void Function(Todo todo, DateTime day)? onOpenTodo,
    required DateTime? now,
    required ValueChanged<EventOccurrence>? onTap,
  }) {
    // L'ora conta **al minuto**: la linea dell'ora deve poter scorrere, ma
    // `DateTime.now()` cambia a ogni microsecondo e invaliderebbe la memoria a ogni
    // ricostruzione.
    final minuto = now == null
        ? null
        : DateTime(now.year, now.month, now.day, now.hour, now.minute);

    // Le occorrenze sono la **stessa lista** finché i dati non cambiano
    // (`EventProvider` tiene la finestra in cache): si confronta l'identità,
    // confrontare il contenuto costerebbe quanto ricostruire.
    //
    // I todo invece sono una mappa **nuova** a ogni ricostruzione: nella chiave
    // entra il **modo** e non la mappa. I todo in sé cambiano solo quando cambia
    // la generazione, e quella è già nella chiave della vista che ci contiene.
    final chiave = (
      giorni.first,
      larghezza,
      minuto,
      identityHashCode(occurrences),
      chiaveTodo,
    );
    if (_timeline != null && _chiave == chiave) return _timeline!;

    _chiave = chiave;
    return _timeline = WeekTimeline(
      days: giorni,
      width: larghezza,
      occurrences: occurrences,
      todosByDay: todosByDay,
      isDone: isDone,
      onTodo: onTodo,
      onOpenTodo: onOpenTodo,
      now: now,
      onTap: onTap,
    );
  }
}
