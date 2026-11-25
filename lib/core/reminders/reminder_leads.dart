/// L'etichetta di un anticipo del promemoria: `15 min`, `1 ora`, `1 giorno`.
///
/// Una sola implementazione perché la usano il form, le impostazioni e (dopo) le
/// notifiche: tre modi di scrivere «1440» sono tre modi di sbagliarlo.
String leadLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  if (minutes < 1440) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0
        ? '$hours or${hours == 1 ? 'a' : 'e'}'
        : '$hours h $rest min';
  }
  final days = minutes ~/ 1440;
  return '$days giorn${days == 1 ? 'o' : 'i'}';
}

/// Gli anticipi che si possono scegliere, in ordine: i valori del piano.
const List<int> standardLeads = [5, 10, 15, 30, 60, 1440];

/// Il tetto di un anticipo: una settimana. Oltre è un dato corrotto, non un
/// promemoria — anche perché la pianificazione copre solo i prossimi 30 giorni.
const int maxReminderLeadMinutes = 7 * 24 * 60;

/// Gli anticipi di un singolo elemento, come stanno nella colonna
/// `reminder_leads`.
///
/// Tre stati in una colonna sola: `null` = «usa il default delle impostazioni»,
/// elenco vuoto = «nessun promemoria per questo elemento», altrimenti i minuti
/// di anticipo, dal più piccolo. Il testo (`"15,60"`) è quello che viaggia nel
/// record di sync, quindi va scritto in modo stabile: ordinato e senza doppioni.
String? encodeReminderLeads(List<int>? leads) {
  if (leads == null) return null;
  return (leads.toSet().toList()..sort()).join(',');
}

/// L'inverso di [encodeReminderLeads], tollerante: un valore assurdo si scarta
/// da solo e il resto dell'elenco resta buono, che è quello che serve quando il
/// record arriva da un altro dispositivo.
List<int>? decodeReminderLeads(Object? raw) {
  if (raw == null) return null;

  final leads = <int>{};
  for (final token in raw.toString().split(',')) {
    final minutes = int.tryParse(token.trim());
    if (minutes == null || minutes < 0 || minutes > maxReminderLeadMinutes) {
      continue;
    }
    leads.add(minutes);
  }
  return leads.toList()..sort();
}
