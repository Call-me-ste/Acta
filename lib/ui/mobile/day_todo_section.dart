import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/todos/domain/todo.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/todos/todo_recurrence.dart';
import '../../theme/design_tokens.dart';
import '../shared/feedback.dart';
import '../shared/motion.dart';
import 'item_detail_sheet.dart';
import 'todo_compact_row.dart';

/// I todo del giorno selezionato, in una fascia richiudibile: **sotto la
/// griglia** nella vista mese, **in fondo** nella vista giorno.
///
/// E' il "pulldown": la barretta dice che la fascia si tira, e il tocco la apre.
/// Chiusa di default, perche' il calendario e' il protagonista e la fascia e' un
/// promemoria. Lo stato aperto/chiuso sta nello state del widget, quindi
/// sopravvive al cambio di giorno selezionato (il parent si limita a
/// ricostruire); non sopravvive all'uscita dal calendario, e va bene cosi'.
///
/// ponytail: quando l'ultimo todo esce dalle griglie (lo scorrimento a destra)
/// la fascia esce dall'albero, e con lei lo stato aperto/chiuso — l'annulla la fa
/// tornare **chiusa**. Si accetta: il conteggio e il badge dicono che e' tornata,
/// e tenere montata la fascia vuota costa una riga in due viste (una delle due e'
/// al tetto delle 300). Se da' noia, si sposta lo stato aperto nel parent.
class DayTodoSection extends StatefulWidget {
  const DayTodoSection({
    super.key,
    required this.day,
    required this.todos,
    this.maxVisible = 20,
  });

  final DateTime day;

  /// I todo da mostrare quel giorno, già filtrati dal filtro condiviso: **fatti
  /// compresi** (il fatto si vede dalla spunta) e senza quelli col segno «via dal
  /// calendario».
  final List<Todo> todos;

  /// Oltre questa soglia si dice quanti ne restano invece di allungare la
  /// sezione all'infinito: il resto si gestisce dalla scheda Todo.
  final int maxVisible;

  @override
  State<DayTodoSection> createState() => _DayTodoSectionState();
}

class _DayTodoSectionState extends State<DayTodoSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = widget.todos.take(widget.maxVisible).toList();
    final hidden = widget.todos.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Semantica di bottone esplicita: l'intestazione apre e chiude la
        // sezione, e un lettore di schermo deve dirlo.
        Semantics(
          button: true,
          onTap: () => setState(() => _open = !_open),
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              child: Row(
                children: [
                  // La barretta: il gesto dice "questa fascia si tira".
                  Container(
                    width: 28,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.bar),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      'To do del giorno (${widget.todos.length})',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        // AnimatedSize e non AnimatedCrossFade: il crossfade tiene il figlio
        // nascosto MONTATO nell'albero (Visibility.maintain), quindi i todo
        // restano trovabili/screen-reader-abili anche da chiusi. Così, da
        // chiusa, le righe non ci sono proprio.
        AnimatedSize(
          // Il sistema può chiedere meno movimento: allora la durata è zero,
          // non "più veloce".
          duration:
              animationsOn(context) ? AppMotion.springDuration : Duration.zero,
          curve: AppMotion.spring,
          child: _open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final todo in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: TodoCompactRow(
                          todo: todo,
                          card: true,
                          // Fatto **in questo giorno**: per un ricorrente e'
                          // l'occorrenza, per uno singolo e' il todo.
                          done: context.read<TodoProvider>().isDoneOn(
                                todo,
                                widget.day,
                              ),
                          // Nella striscia del calendario lo scorrimento a destra
                          // toglie il todo dalle griglie.
                          dalCalendario: true,
                          onOpen: () => showItemDetail(
                            context,
                            todo: todo,
                            day: widget.day,
                          ),
                          onToggle: () {
                            tickFeedback();
                            context
                                .read<TodoProvider>()
                                .toggleForDay(todo, widget.day);
                          },
                        ),
                      ),
                    if (hidden > 0)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppSpacing.m,
                          bottom: AppSpacing.s,
                        ),
                        child: Text(
                          'e altri $hidden To do',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
