import 'package:flutter/material.dart';

import '../../features/events/domain/time_rules.dart';
import '../shared/date_math.dart';
import 'pickers.dart';

// Chiedere giorno e ora di un elemento: quello che il form fa quando si tocca
// una riga.
//
// Sta fuori dal form perche' **non tocca il suo stato** (prende i valori di
// adesso e torna quelli scelti) e perche' il form ha un budget di righe da
// rispettare (`test/architecture_test.dart`): si estrae, non si alza il tetto.

/// Sul giorno corrente propone il prossimo slot. Sugli altri giorni 09:00.
(TimeOfDay, TimeOfDay) orarioEventoPredefinito(DateTime giorno, DateTime ora) {
  final minuti = ora.hour * 60 + ora.minute;
  final prossimo = (minuti ~/ 30 + 1) * 30;
  final inizio = dateOnly(giorno) == dateOnly(ora)
      ? prossimo.clamp(0, EventTimeRules.lastMinuteOfDay - 1)
      : 9 * 60;
  final fine = EventTimeRules.endFor(
    startMinutes: inizio,
    currentEndMinutes: inizio,
  );
  TimeOfDay dalle(int minuti) =>
      TimeOfDay(hour: minuti ~/ 60, minute: minuti % 60);
  return (dalle(inizio), dalle(fine));
}

/// Il giorno dell'elemento.
Future<DateTime?> askItemDay(BuildContext context, DateTime current) {
  return pickDate(context,
      initial: current,
      firstYear: current.year < 1900 ? current.year : 1900,
      lastYear: current.year > 2100 ? current.year : 2100);
}

/// La scadenza di un todo. Senza scadenza si parte da oggi; il tetto degli anni
/// e' lo stesso del calendario delle scadenze (2035).
Future<DateTime?> askItemDueDate(BuildContext context, DateTime? current) {
  return pickDate(
    context,
    initial: current ?? DateTime.now(),
    lastYear: 2035,
  );
}

/// L'orario **di un todo**, in minuti dalla mezzanotte: solo quel lato, senza le
/// regole di completamento degli eventi.
///
/// Per un todo «dalle 8» e «entro le 18» sono due cose diverse e legittime; per
/// un evento le due estremita' si aggiustano a vicenda, perche' un evento e'
/// sempre un intervallo. Torna `null` se si annulla.
Future<int?> askTodoTime(BuildContext context, {int? current}) async {
  final picked = await pickTime(
    context,
    initial: current == null
        ? const TimeOfDay(hour: 8, minute: 0)
        : TimeOfDay(hour: current ~/ 60, minute: current % 60),
  );
  if (picked == null) return null;
  return picked.hour * 60 + picked.minute;
}

/// Le due estremita' di un evento **insieme**: spostando l'inizio oltre la fine
/// (o viceversa) l'altra si sposta con lei, che e' quello che ci si aspetta da
/// un orario. Torna `null` se si annulla.
Future<({TimeOfDay start, TimeOfDay end})?> askItemTime(
  BuildContext context, {
  required TimeOfDay start,
  required TimeOfDay end,
  required bool isStart,
  bool sameDay = true,
}) async {
  final picked = await pickTime(context, initial: isStart ? start : end);
  if (picked == null) return null;
  if (!sameDay) {
    return (start: isStart ? picked : start, end: isStart ? end : picked);
  }

  final (newStart, newEnd) = adjustedTimes(
    start: start,
    end: end,
    pickedStart: isStart,
    picked: picked,
  );
  return (start: newStart, end: newEnd);
}
