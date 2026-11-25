import 'package:intl/intl.dart';

import 'domain/reminder_plan.dart';

String titoloPromemoria(ScheduledReminder avviso) {
  if (avviso.title.trim().isNotEmpty) return avviso.title;
  return switch (avviso.kind) {
    ReminderKind.evento || ReminderKind.tuttoIlGiorno => 'Evento',
    ReminderKind.todo => 'To do',
    ReminderKind.riepilogo => 'Scadenze da confermare',
  };
}

String descriviPromemoria(ScheduledReminder avviso) {
  if (avviso.kind == ReminderKind.riepilogo) {
    return 'Rivedi eventi e To do scaduti';
  }
  final data = avviso.itemDate;
  if (data == null) return '';

  final base = DateTime(avviso.when.year, avviso.when.month, avviso.when.day);
  final oggi = DateTime(data.year, data.month, data.day);
  final domani = DateTime(base.year, base.month, base.day + 1);
  final giorno = oggi == base
      ? 'Oggi'
      : oggi == domani
          ? 'Domani'
          : DateFormat('EEE d MMM', 'it_IT').format(data);
  final ora = switch (avviso.kind) {
    ReminderKind.tuttoIlGiorno => 'Tutto il giorno',
    _ when avviso.hasTime => DateFormat('HH:mm').format(data),
    _ => '',
  };
  final principale = ora.isEmpty ? giorno : '$giorno · $ora';
  final luogo = avviso.location.trim();
  return luogo.isEmpty ? principale : '$principale\n$luogo';
}
