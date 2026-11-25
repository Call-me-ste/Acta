import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/events/domain/event_occurrence.dart';
import '../../features/todos/domain/todo.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/todos/todo_recurrence.dart';
import '../../theme/design_tokens.dart';
import '../shared/event_colors.dart';
import 'day_header.dart';
import 'day_timeline.dart';
import 'item_detail_sheet.dart';
import 'todo_compact_row.dart';

/// La giornata: gli eventi **senza orario** e i todo **senza orario** in cima,
/// poi la timeline delle 24 ore.
///
/// I todo senza orario stanno **fuori dallo scorrimento**, come gli eventi di
/// giornata intera: non hanno un'ora a cui stare, e dentro lo scorrimento — sotto
/// le 24 ore — non li vedeva nessuno (segnalato: «in Pieni non si vedono le
/// todo», e per vederli serviva scorrere fino a dopo le 23).
///
/// La griglia è alta ~1150 px e si scorre da sola (la sua `ListView`), mentre la
/// riga all-day resta fissa: è l'intestazione del giorno, non va cercata.
class DayView extends StatefulWidget {
  const DayView({
    super.key,
    required this.day,
    required this.occurrences,
    required this.todos,
    required this.pieno,
    this.now,
    this.onTap,
    this.onOpenTodo,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onPickMonth,
  });

  final DateTime day;

  /// Le occorrenze **di questo giorno**, all-day comprese: la separazione la fa
  /// la vista, così chi la usa non deve sapere com'è fatta una giornata.
  final List<EventOccurrence> occurrences;

  /// I todo del giorno, già filtrati dal provider (`todosForDate`).
  final List<Todo> todos;

  /// «Pieni»: i todo stanno **dentro la giornata** — quelli con un orario nella
  /// griglia delle ore, quelli senza orario nella riga sotto l'intestazione —
  /// invece della fascia richiudibile in fondo. In quel modo la fascia non si
  /// mostra: sarebbero gli stessi todo in due posti.
  final bool pieno;

  /// L'istante attuale, per la linea dell'ora. `null` nei test: una riga che si
  /// sposta da sola non è una cosa da verificare.
  final DateTime? now;

  final ValueChanged<EventOccurrence>? onTap;

  /// Tocco su una riga del foglio del cluster: apre il form del todo (gli
  /// stessi callback della vista settimana).
  final void Function(Todo todo, DateTime day)? onOpenTodo;

  /// Giorno prima/dopo dalle freccette: un tap, un salto netto.
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  /// Apre la scelta di mese e anno (come l'intestazione del mese e della
  /// settimana): la stessa cosa si fa allo stesso modo nelle tre viste.
  final VoidCallback onPickMonth;

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    // Si apre intorno alle 7: aprire a mezzanotte mostrerebbe una griglia vuota
    // e la giornata comincerebbe con uno scroll da fare a mano.
    _controller = ScrollController(
      initialScrollOffset: 7 * DayTimeline.defaultHourHeight,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allDay = widget.occurrences
        .where((occurrence) => occurrence.event.allDay)
        .toList();
    final timed = widget.occurrences
        .where((occurrence) => !occurrence.event.allDay)
        .toList();
    // I todo con orario vanno nella griglia (li disegna la timeline); quelli
    // senza orario li mostra la riga qui sotto.
    final senzaOrario = [
      for (final todo in widget.todos)
        if (todo.firstTime == null) todo,
    ];

    // La riga all-day sta FUORI dallo scroll: si apre il giorno e la si vede,
    // senza andare a cercarla scrorrendo le ore.
    return Column(
      children: [
        // La data che si sta guardando, in cima: era l'unica vista a non dirlo.
        DayHeader(
          day: widget.day,
          onPrevious: widget.onPreviousDay,
          onNext: widget.onNextDay,
          onPick: widget.onPickMonth,
        ),
        if (allDay.isNotEmpty)
          _AllDayRow(occurrences: allDay, onTap: widget.onTap),
        // I todo **senza orario** non stanno "da qualche parte" nella giornata:
        // stanno con gli eventi di giornata intera, sopra la griglia delle ore,
        // dove si vedono appena si apre il giorno. Dentro lo scorrimento — in
        // fondo alle 24 ore — c'erano lo stesso, ma sotto la piega: e' la
        // segnalazione.
        if (widget.pieno && senzaOrario.isNotEmpty)
          _TodoRow(todos: senzaOrario, day: widget.day),
        Expanded(
          child: ListView(
            controller: _controller,
            padding: const EdgeInsets.only(
              bottom: AppSpacing.calendarActionsClearance,
            ),
            children: [
              DayTimeline(
                day: widget.day,
                occurrences: timed,
                todos: widget.pieno ? widget.todos : const [],
                onTodo: (todo) =>
                    context.read<TodoProvider>().toggleForDay(todo, widget.day),
                // Fatto in **questo** giorno (per un ricorrente e'
                // l'occorrenza): la casella resta, sbiadita.
                isDone: (todo) =>
                    context.read<TodoProvider>().isDoneOn(todo, widget.day),
                now: widget.now,
                onTap: widget.onTap,
                onOpenTodo: widget.onOpenTodo,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// I todo del giorno nella modalita' **«Pieni»**: righe vere, fuori dallo
/// scorrimento delle ore (come la riga degli eventi senza orario), con l'orario
/// accanto alla priorita' — le stesse righe della fascia, ma sempre in vista.
class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.todos, required this.day});

  final List<Todo> todos;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<TodoProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        0,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('To do del giorno (${todos.length})',
              style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final todo in todos)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: TodoCompactRow(
                todo: todo,
                card: true,
                done: provider.isDoneOn(todo, day),
                // In «Pieni» lo scorrimento a destra toglie il todo dalle griglie,
                // come nella striscia.
                dalCalendario: true,
                onOpen: () => showItemDetail(
                  context,
                  todo: todo,
                  day: day,
                ),
                onToggle: () => provider.toggleForDay(todo, day),
              ),
            ),
        ],
      ),
    );
  }
}

/// Gli eventi senza orario: non stanno "da qualche parte" nella giornata, quindi
/// vivono fuori dalla griglia.
class _AllDayRow extends StatelessWidget {
  const _AllDayRow({required this.occurrences, this.onTap});

  final List<EventOccurrence> occurrences;
  final ValueChanged<EventOccurrence>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tutto il giorno', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.xs,
            children: [
              for (final occurrence in occurrences)
                ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: occurrenceColor(context, occurrence),
                    radius: 6,
                  ),
                  label: Text(occurrence.title),
                  onPressed: onTap == null ? null : () => onTap!(occurrence),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
