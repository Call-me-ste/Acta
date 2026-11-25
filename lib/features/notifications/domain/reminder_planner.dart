import '../../../core/sync/hash.dart';
import '../../recurrence/domain/recurrence_expansion.dart';
import '../../recurrence/domain/recurrence_rule.dart';
import 'reminder_plan.dart';

/// La chiave di un'occorrenza confermata: `itemId@yyyy-MM-dd`.
///
/// E' la stessa forma che usa `occurrence_overrides` per il suo `id`: un elemento
/// confermato non deve piu' avvisare, e questa e' la domanda da fare.
String occurrenceKey(String itemId, DateTime day) {
  final mese = day.month.toString().padLeft(2, '0');
  final giorno = day.day.toString().padLeft(2, '0');
  return '$itemId@${day.year}-$mese-$giorno';
}

/// L'identificativo **stabile** di un promemoria, per Android.
///
/// Stabile vuol dire: lo stesso (elemento, giorno, anticipo) da' sempre lo stesso
/// numero, anche dopo un riavvio dell'app. Cosi' ripianificare **sostituisce**
/// l'avviso invece di aggiungerne un secondo — che e' il modo classico in cui le
/// notifiche si moltiplicano.
///
/// Si maschera a 31 bit perche' Android vuole un `int` positivo; la parte bassa
/// dell'hash basta e avanza per non avere collisioni fra poche decine di avvisi.
int reminderIdFor(String itemId, DateTime day, int leadMinutes) {
  final chiave = '${occurrenceKey(itemId, day)}#$leadMinutes';
  final esadecimale = fnv1a64Hex(chiave.codeUnits);
  return int.parse(esadecimale.substring(0, 7), radix: 16);
}

/// Calcola i promemoria di una finestra: **quando** avvisare, per cosa, con che
/// voce.
///
/// Sta fuori dalla UI (e fuori dal plugin delle notifiche) perche' e' la parte da
/// poter leggere e provare con numeri: "quali avvisi nascono da questi eventi, in
/// questa finestra" e' una domanda di dominio, e ha una risposta esatta.
///
/// Regole, tutte con il loro motivo:
/// - un elemento **confermato o completato** non avvisa piu' (l'utente ha gia'
///   risposto alla domanda che l'avviso poneva);
/// - un avviso **gia' passato** non si recupera: si pianifica solo da adesso in
///   avanti, cosi' aprire l'app non fa piovere notifiche vecchie;
/// - gli eventi **tutto il giorno** non hanno un anticipo da calcolare: avvisano a
///   un'ora fissa del giorno stesso;
/// - gli anticipi di un elemento sono **piu' d'uno** (una lista): un evento puo'
///   avvisare sia il giorno prima sia un'ora prima;
/// - le **ore silenziose** non scartano l'avviso, lo rendono muto (visibile senza
///   suono): perderlo sarebbe peggio che farlo silenzioso;
/// - si pianifica solo la **finestra** (30 giorni di default) e non oltre il
///   **tetto** (64), perche' il sistema non gradisce code lunghe.
List<ScheduledReminder> planReminders(
  ReminderInputs inputs, {
  QuietHours? quiet,
}) {
  final fine = inputs.now.add(inputs.window);
  bool dentroFinestra(DateTime when) =>
      !when.isBefore(inputs.now) && !when.isAfter(fine);

  ScheduledReminder? build({
    required String itemId,
    required DateTime day,
    required DateTime when,
    required String title,
    required ReminderKind kind,
    required bool? sound,
    required int lead,
    required DateTime itemDate,
    bool hasTime = false,
    String location = '',
  }) {
    if (!dentroFinestra(when)) return null;
    if (inputs.doneOccurrences.contains(occurrenceKey(itemId, day))) {
      return null;
    }
    return ScheduledReminder(
      id: reminderIdFor(itemId, day, lead),
      itemId: itemId,
      when: when,
      title: title,
      kind: kind,
      itemDate: itemDate,
      hasTime: hasTime,
      location: location,
      sound: sound ?? inputs.soundDefault,
      quiet: quiet != null && isQuiet(when, quiet),
    );
  }

  final pianificati = <ScheduledReminder>[];

  for (final occurrence in inputs.occurrences) {
    final event = occurrence.event;
    final giorno = occurrence.date;

    if (event.allDay) {
      if (event.reminderLeads?.isEmpty ?? false) continue;
      // Un anticipo su un evento senza orario non vuol dire niente: si avvisa la
      // mattina del giorno stesso, e una volta sola.
      final quando = DateTime(
        giorno.year,
        giorno.month,
        giorno.day,
        inputs.allDayMinuteOfDay ~/ 60,
        inputs.allDayMinuteOfDay % 60,
      );
      final avviso = build(
        itemId: event.id,
        day: giorno,
        when: quando,
        title: event.title,
        kind: ReminderKind.tuttoIlGiorno,
        itemDate: giorno,
        location: event.location,
        sound: event.reminderSound,
        lead: 0,
      );
      if (avviso != null) pianificati.add(avviso);
      continue;
    }

    // `null` = default delle impostazioni, elenco vuoto = nessun promemoria.
    final anticipi = event.reminderLeads ?? [inputs.eventLead];
    for (final lead in anticipi) {
      final avviso = build(
        itemId: event.id,
        day: giorno,
        when: occurrence.start.subtract(Duration(minutes: lead)),
        title: event.title,
        kind: ReminderKind.evento,
        itemDate: occurrence.start,
        hasTime: true,
        location: event.location,
        sound: event.reminderSound,
        lead: lead,
      );
      if (avviso != null) pianificati.add(avviso);
    }
  }

  for (final todo in inputs.todos) {
    final scadenza = todo.dueDate;
    // Un todo senza scadenza non ha un momento in cui avvisare.
    if (scadenza == null || todo.completed) continue;

    final regola = RecurrenceRule.tryParse(todo.recurrenceRule);
    final giorni = regola == null
        ? [scadenza]
        : expandOccurrences(
            regola,
            start: scadenza,
            rangeStart:
                DateTime(inputs.now.year, inputs.now.month, inputs.now.day),
            rangeEnd: DateTime(fine.year, fine.month, fine.day + 2),
          );
    final anticipi = todo.reminderLeads ?? [inputs.todoLead];
    final ora = todo.startMinutes ?? inputs.todoMinuteOfDay;
    for (final giorno in giorni) {
      final scadenzaAvviso = DateTime(
        giorno.year,
        giorno.month,
        giorno.day,
        ora ~/ 60,
        ora % 60,
      );
      for (final lead in anticipi) {
        final avviso = build(
          itemId: todo.id,
          day: giorno,
          when: scadenzaAvviso.subtract(Duration(minutes: lead)),
          title: todo.title,
          kind: ReminderKind.todo,
          itemDate: scadenzaAvviso,
          hasTime: todo.startMinutes != null,
          location: todo.location,
          sound: todo.reminderSound,
          lead: lead,
        );
        if (avviso != null) pianificati.add(avviso);
      }
    }
  }

  pianificati.sort((a, b) => a.when.compareTo(b.when));
  return pianificati.take(inputs.maxReminders).toList();
}
