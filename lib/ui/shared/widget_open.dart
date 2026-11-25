import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/calendar/giorno_richiesto.dart';
import '../../features/events/event_provider.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/widgets/domain/widget_payload.dart';
import '../../features/widgets/widget_bridge.dart';
import '../../features/widgets/widget_contract.dart';
import '../mobile/item_sheet.dart';
import 'widget_countdown.dart';

/// Il navigatore del guscio: i fogli aperti dai widget stanno **sopra**
/// `MaterialApp` (la guardia non è dentro il Navigator) e ne hanno bisogno.
final GlobalKey<NavigatorState> naveDaWidget = GlobalKey<NavigatorState>();

/// Apre quello che un widget ha chiesto: un giorno, un elemento, il form di un
/// nuovo evento o il selettore del countdown.
void apriDaWidget(
  BuildContext context,
  Uri? uri, {
  required WidgetBridge ponte,
  EventProvider? eventi,
  TodoProvider? todos,
}) {
  final tocca = leggiToccaDelWidget(uri);
  if (tocca == null) return;
  final contesto = naveDaWidget.currentContext ?? context;

  if (tocca.azione == 'nuovo') {
    unawaited(
      showItemForm(
        contesto,
        type: ItemType.evento,
        day: tocca.giorno ?? DateTime.now(),
      ),
    );
    return;
  }

  if (tocca.azione == 'countdown') {
    final widgetId = tocca.widget;
    if (widgetId == null || eventi == null) return;
    final oggi = DateTime.now();
    final primo = DateTime(oggi.year, oggi.month, oggi.day);
    final occorrenze = eventi.occurrencesBetween(
      primo,
      primo.add(const Duration(days: 92)),
    );
    unawaited(
      mostraSelettoreCountdown(
        contesto,
        widgetId: widgetId,
        ponte: ponte,
        occorrenze: occorrenze,
      ),
    );
    return;
  }

  if (tocca.azione != 'apri') return;
  final id = tocca.id;
  final tipo = tocca.tipo;
  if (id == null || tipo == null) {
    final giorno = tocca.giorno;
    if (giorno == null) return;
    giornoRichiestoDi(contesto)?.chiedi(giorno);
    return;
  }

  if (tipo == tipoTodo) {
    final todo = todos?.todos.where((elemento) => elemento.id == id).firstOrNull;
    if (todo == null) return;
    unawaited(
      showItemForm(
        contesto,
        type: ItemType.todo,
        day: todo.dueDate ?? tocca.giorno ?? DateTime.now(),
        todo: todo,
      ),
    );
    return;
  }

  final evento =
      eventi?.events.where((elemento) => elemento.id == id).firstOrNull;
  if (evento == null) return;
  unawaited(
    showItemForm(
      contesto,
      type: ItemType.evento,
      day: tocca.giorno ?? evento.start,
      event: evento,
    ),
  );
}
