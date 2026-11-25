import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/categories/category_controller.dart';
import '../../features/events/domain/time_rules.dart';
import 'category_chips.dart';

/// I tre selettori del form, senza lo `setState` dentro: restituiscono il valore
/// scelto (o `null` se si annulla) e il form decide cosa farne.
///
/// Stanno qui perché i range di date erano due numeri sparsi in metà diversi
/// dello stesso file, e perché così il form resta breve: la parte lunga di un
/// form è sempre la stessa — tre picker e un salvataggio.
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  int firstYear = 2020,
  int lastYear = 2030,
}) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(firstYear),
    lastDate: DateTime(lastYear, 12, 31),
  );
}

Future<TimeOfDay?> pickTime(
  BuildContext context, {
  required TimeOfDay initial,
}) {
  return showTimePicker(context: context, initialTime: initial);
}

/// La categoria da dare a quello che si sta modificando.
///
/// Restituisce gli id scelti (`[]` per «nessuna») oppure `null` se si annulla: la
/// differenza **conta**, perche' «nessuna» e' una scelta e l'annulla no. Una per
/// volta, come nel form.
Future<List<String>?> pickCategory(BuildContext context) {
  final categorie = context.read<CategoryController>().all;

  return showActaSheet<List<String>>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            dense: true,
            title: Text('Categoria'),
          ),
          ListTile(
            key: const ValueKey('categoria-nessuna'),
            leading: const Icon(Icons.block),
            title: const Text('Nessuna'),
            onTap: () => Navigator.pop(context, const <String>[]),
          ),
          for (final categoria in categorie)
            ListTile(
              key: ValueKey('categoria-${categoria.id}'),
              leading: CategoryDot(category: categoria),
              title: Text(categoria.name),
              onTap: () => Navigator.pop(context, [categoria.id]),
            ),
        ],
      ),
    ),
  );
}

/// La coppia di orari aggiornata dopo che l'utente ne ha scelto uno: applica le
/// regole dei campi incompleti (chi scrive «dalle 21» intende un'ora) e rende la
/// nuova coppia tutta insieme, così il form non le tiene mai in disaccordo.
(TimeOfDay, TimeOfDay) adjustedTimes({
  required TimeOfDay start,
  required TimeOfDay end,
  required bool pickedStart,
  required TimeOfDay picked,
}) {
  int minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;
  TimeOfDay timeOf(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  if (pickedStart) {
    return (
      picked,
      timeOf(EventTimeRules.endFor(
        startMinutes: minutesOf(picked),
        currentEndMinutes: minutesOf(end),
      )),
    );
  }
  return (
    timeOf(EventTimeRules.startFor(
      endMinutes: minutesOf(picked),
      currentStartMinutes: minutesOf(start),
    )),
    picked,
  );
}
