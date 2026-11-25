import 'reminder_plan.dart';
import 'reminder_planner.dart';

/// I **riepiloghi della sera**: uno per ognuna delle prossime sere, alle
/// `oraRiepilogo`.
///
/// Perché il riepilogo non si pianifica come gli altri tre avvisi: una notifica
/// si prepara **prima**, ma «ci sarà qualcosa da confermare stasera alle 20:00?»
/// dipende da quello che si fa nel pomeriggio. Quindi:
///
/// - il **testo è generico** («Scadenze da confermare»): il contenuto vero lo
///   mostra il foglio degli scaduti, che si apre già all'apertura dell'app;
/// - la finestra è **corta** (sette sere, non i trenta giorni degli altri): se
///   l'app resta chiusa una settimana i riepiloghi si fermano, e a riaprirla si
///   ricalcolano. È dichiarato, non è un difetto nascosto;
/// - l'id è quello **stabile** di una occorrenza finta (`riepilogo@AAAA-MM-GG`,
///   anticipo 0), così ricalcolare sostituisce il riepilogo di quella sera invece
///   di aggiungerne un secondo.
///
/// Il chiamante decide **se** pianificarli (in `NotificationScheduler`: solo se
/// c'è qualcosa da confermare, e solo se il tipo è acceso).
List<ScheduledReminder> riepiloghiDellaSera({
  required DateTime adesso,
  required int oraRiepilogo,
  int sere = 7,
  QuietHours? quiet,
}) {
  final riepiloghi = <ScheduledReminder>[];
  final ora = oraRiepilogo ~/ 60;
  final minuto = oraRiepilogo % 60;

  for (var i = 0; i < sere; i++) {
    final sera = DateTime(adesso.year, adesso.month, adesso.day + i, ora, minuto);
    // La sera di oggi si pianifica solo se non è ancora passata: un avviso nel
    // passato non si recupera (stessa regola del pianificatore).
    if (!sera.isAfter(adesso)) continue;

    riepiloghi.add(
      ScheduledReminder(
        id: reminderIdFor(riepilogoItemId, sera, 0),
        itemId: riepilogoItemId,
        when: sera,
        title: 'Scadenze da confermare',
        kind: ReminderKind.riepilogo,
        // Il riepilogo è silenzioso per progetto, e il canale lo sa già: qui si
        // dice solo che non deve suonare, per chi legge il piano.
        sound: false,
        quiet: quiet != null && isQuiet(sera, quiet),
      ),
    );
  }

  return riepiloghi;
}

/// L'elemento finto da cui nascono i riepiloghi: non è un evento né un todo, ma
/// serve un nome stabile per costruire l'id e per il carico della notifica.
const String riepilogoItemId = 'riepilogo';
