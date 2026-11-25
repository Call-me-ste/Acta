import '../../events/domain/event_occurrence.dart';
import '../../todos/domain/todo.dart';

/// Che tipo di avviso e': decide il **canale** Android (importanza e suono) e la
/// forma del testo. Quattro tipi e tre canali, perche' quattro canali sarebbero
/// quattro posti in cui l'utente deve cercare il silenzio: i due tipi di evento
/// (con orario e tutto il giorno) suonano nello stesso canale.
enum ReminderKind {
  evento,
  todo,
  tuttoIlGiorno,

  /// Il **riepilogo della sera**: le scadenze da confermare. Non nasce da un
  /// elemento ma dall'insieme degli scaduti, quindi e' l'unico tipo che il
  /// pianificatore non produce da un evento o un todo.
  riepilogo,
}

/// Un promemoria **gia' calcolato**: quando avvisare, per cosa, e con che voce.
///
/// Non si scrive sul database (i promemoria sono stato derivato: si ricalcolano),
/// ma ha tutto quello che serve a chi li pianifica davvero.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.itemId,
    required this.when,
    required this.title,
    required this.kind,
    required this.sound,
    required this.quiet,
    this.itemDate,
    this.hasTime = false,
    this.location = '',
  });

  /// Identificativo **stabile**: lo stesso promemoria, ricalcolato, tiene lo stesso
  /// `id`, cosi' una modifica *sostituisce* l'avviso invece di duplicarlo.
  final int id;

  /// L'elemento da cui nasce (evento o todo).
  final String itemId;

  final DateTime when;
  final String title;
  final ReminderKind kind;
  final DateTime? itemDate;
  final bool hasTime;
  final String location;

  /// Se questo avviso deve suonare (impostazione dell'elemento, se c'e').
  final bool sound;

  /// Vero se cade nelle **ore silenziose**: resta visibile ma senza suono ne'
  /// vibrazione. Scartarlo sarebbe peggio: un promemoria che non arriva non si
  /// recupera.
  final bool quiet;

  /// Suona solo se l'elemento lo prevede **e** non siamo in ore silenziose.
  bool get loud => sound && !quiet;

  @override
  String toString() => 'ScheduledReminder($when, $title, $kind, loud: $loud)';
}

/// Le ore silenziose, in minuti dalla mezzanotte. Possono scavalcare la mezzanotte
/// (22:00 → 07:00 e' il caso normale), quindi non sono un intervallo normale.
typedef QuietHours = ({int start, int end});

bool isQuiet(DateTime when, QuietHours hours) {
  if (hours.start == hours.end) return false;
  final minutes = when.hour * 60 + when.minute;
  return hours.start < hours.end
      ? minutes >= hours.start && minutes < hours.end
      : minutes >= hours.start || minutes < hours.end;
}

/// Tutto quello che serve per calcolare i promemoria di una finestra.
class ReminderInputs {
  const ReminderInputs({
    required this.now,
    required this.occurrences,
    required this.todos,
    required this.doneOccurrences,
    required this.eventLead,
    required this.todoLead,
    required this.todoMinuteOfDay,
    required this.allDayMinuteOfDay,
    required this.soundDefault,
    this.window = const Duration(days: 30),
    this.maxReminders = 64,
  });

  final DateTime now;

  /// Le occorrenze degli eventi nella finestra (ricorrenti gia' espanse).
  final List<EventOccurrence> occurrences;

  /// I todo: si considerano quelli con una scadenza.
  final List<Todo> todos;

  /// Le occorrenze gia' confermate (o i todo fatti): `itemId@yyyy-MM-dd`. Un
  /// elemento confermato **non avvisa piu'**.
  final Set<String> doneOccurrences;

  /// Anticipo di default, in minuti: quello delle impostazioni, usato quando
  /// l'elemento non dice niente.
  final int eventLead;
  final int todoLead;

  /// Minuti dalla mezzanotte per i To do senza orario.
  final int todoMinuteOfDay;

  /// Minuti dalla mezzanotte per un evento "tutto il giorno" (i minuti di anticipo
  /// non hanno senso: non c'e' un orario da anticipare).
  final int allDayMinuteOfDay;

  /// Il suono di default delle impostazioni: usato quando l'elemento non dice
  /// niente (il suo campo e' a tre stati, `null` = eredita).
  final bool soundDefault;

  /// Quanto avanti si pianifica: oltre non si materializza niente, e si ricalcola
  /// quando l'app torna in primo piano.
  final Duration window;

  /// Il tetto di sistema: Android non gradisce code lunghe, e una pianificazione
  /// enorme e' anche un costo.
  final int maxReminders;
}
