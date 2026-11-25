import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/calendar/day_axis.dart';
import '../../features/events/domain/event_occurrence.dart';
import '../../features/filters/filtro_condiviso.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/domain/todo.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/todos/todo_windows.dart';
import 'day_pager.dart';
import 'day_todo_section.dart';
import 'day_view.dart';
import 'item_detail_sheet.dart';

/// Quello che si vede nella **vista giorno**: il pager che scorre da un giorno
/// all'altro e, **in fondo**, la fascia apribile dei todo del giorno scelto.
///
/// Sta in un file suo per la stessa ragione delle altre viste: `calendar_page`
/// e' il posto delle tre viste e delle loro chiavi — la memoria, il giorno
/// scelto, le frecce — non di quello che una vista disegna. Le occorrenze
/// arrivano come **funzione** e non come lista: il pager tiene vivi tre giorni,
/// e chiederle tutte in anticipo sarebbe il lavoro che il pager esiste per non
/// fare.
class DaySection extends StatelessWidget {
  const DaySection({
    super.key,
    required this.day,
    required this.todos,
    required this.occurrencesOf,
    required this.onDaySelected,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onPickMonth,
    required this.modo,
    required this.filtro,
  });

  final DateTime day;

  /// I todo del giorno scelto, **come li da' il provider**: a filtrarli e'
  /// questo widget, con lo stesso filtro che taglia quelli del pager (un posto
  /// solo per le due liste).
  final List<Todo> todos;

  final List<EventOccurrence> Function(DateTime day) occurrencesOf;

  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onPickMonth;

  /// Come si vedono i todo in questa vista: «compatta» la fascia in fondo,
  /// «piena» le righe dentro la giornata, «nascosta» niente. Arriva come
  /// **parametro** e non si legge dalle preferenze qui dentro: un ascolto
  /// ricostruirebbe le viste a ogni cambio di preferenza, anche da nascoste, ed e'
  /// il costo che `CalendarViewCache` esiste per togliere.
  final TodoInCalendario modo;

  /// Il filtro condiviso: i todo delle tre giornate del pager e quelli della
  /// fascia in fondo passano di qui. Arriva come **parametro** (l'ascolto e'
  /// della pagina): vedi `modo`, che ha lo stesso motivo.
  final FiltroCondiviso filtro;

  @override
  Widget build(BuildContext context) {
    final visibili = [
      for (final todo in todos)
        if (filtro.passaTodo(todo)) todo,
    ];

    return Column(
      children: [
        Expanded(
          // Il giorno **segue** la selezione anche quando a cambiarla è il mese
          // o la settimana: la vista resta viva, quindi il `PageView` non può
          // più nascere ogni volta sul giorno giusto.
          child: DayPager(
            selectedDay: day,
            indexOf: DayAxis.indexOf,
            dayAt: DayAxis.dayAt,
            onDaySelected: onDaySelected,
            itemBuilder: (context, giorno) => DayView(
              day: giorno,
              occurrences: occurrencesOf(giorno),
              // I todo **di quel giorno**: il pager tiene vivi tre giorni, e in
              // «Pieni» ognuno mostra i suoi. Si **legge** (non si ascolta):
              // l'ascolto e' della pagina, e la chiave della memoria contiene la
              // generazione dei dati.
              todos: [
                for (final todo in context.read<TodoProvider>().todosForDate(
                      giorno,
                    ))
                  if (filtro.passaTodo(todo)) todo,
              ],
              pieno: modo == TodoInCalendario.pieni,
              now: DateTime.now(),
              onPreviousDay: onPreviousDay,
              onNextDay: onNextDay,
              // Dalla vista giorno la data apre l'elenco delle **settimane** (lo
              // stesso della vista settimana): si salta dove serve, con una
              // schermata in meno da imparare.
              onPickMonth: onPickMonth,
              onTap: (occurrence) => showItemDetail(
                context,
                event: occurrence.event,
                day: occurrence.date,
              ),
              // Il tocco su una riga del foglio del cluster apre la scheda del
              // todo, come nella vista settimana.
              onOpenTodo: (todo, giorno) => showItemDetail(
                context,
                todo: todo,
                day: todo.dueDate ?? giorno,
              ),
            ),
          ),
        ),
        // I todo del giorno **in fondo** e non in alto (richiesta dell'utente):
        // la stessa fascia del mese, chiusa di default, che non ruba spazio alla
        // giornata e si tira su quando serve. La striscia che stava in alto
        // troncava l'elenco («e altri 1 todo») e non si poteva aprire.
        if (visibili.isNotEmpty && modo == TodoInCalendario.compatta)
          DayTodoSection(day: day, todos: visibili),
      ],
    );
  }
}
