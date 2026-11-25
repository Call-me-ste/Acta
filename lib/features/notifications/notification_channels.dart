import '../../core/sync/hash.dart';
import 'domain/reminder_plan.dart';
import 'notification_settings_controller.dart';

/// Che **canale** Android usa un avviso: l'id, come si chiama nel sistema, con
/// che voce arriva e con quanta importanza.
///
/// Perché un valore e non una chiamata al plugin: «quale canale tocca a questo
/// avviso» è una **decisione**, e si prova con i test senza telefono. Il plugin
/// si limita a crearla (in `flutter_local_notifications_sink.dart`, l'unico file
/// che lo importa). L'importanza è un **intero** di Android (2 bassa, 3 media,
/// 4 alta) e non un enum del plugin: così questo file resta senza dipendenze.
///
/// La regola che decide tutto: su Android 8+ suono e vibrazione sono proprietà
/// del canale, e **dopo la creazione non si cambiano più**. Un'impostazione
/// cambiata non aggiorna il canale che c'è: usa un canale **diverso**, che è il
/// motivo per cui l'id porta dentro il suono e la vibrazione.
class CanaleAvviso {
  const CanaleAvviso({
    required this.id,
    required this.nome,
    required this.descrizione,
    required this.importanza,
    required this.suona,
    required this.vibra,
    required this.suonoUri,
  });

  final String id;

  /// Come si legge nelle impostazioni di Android («Eventi», «Todo»,
  /// «Riepiloghi», col suffisso del suono solo quando serve a distinguerli).
  final String nome;

  final String descrizione;

  /// `NotificationManager.IMPORTANCE_*`: 2 bassa, 3 media, 4 alta.
  final int importanza;

  final bool suona;
  final bool vibra;

  /// L'indirizzo del suono (`content://…`), o `null` per quello di sistema.
  final String? suonoUri;

  @override
  String toString() => 'CanaleAvviso($id, $nome, imp: $importanza)';
}

/// Il **codice del suono** dentro l'id del canale: la prima lettera utile del
/// nome, con `x` per «nessuno».
String codiceSuono(String suono) => switch (suono) {
      NotificationSettingsController.suonoSistema => '0',
      NotificationSettingsController.suonoSveglia => '1',
      NotificationSettingsController.suonoSuoneria => '2',
      _ => 'x',
    };

/// Il nome del canale per un tipo di avviso, col suffisso **solo** quando serve
/// a distinguerlo da un altro canale dello stesso tipo: se il suono è quello di
/// sistema non si aggiunge niente, se è «nessuno» si dice che è silenzioso.
String nomeCanale(ReminderKind tipo, String suono) {
  final base = switch (tipo) {
    ReminderKind.todo => 'To do',
    ReminderKind.riepilogo => 'Riepiloghi',
    _ => 'Eventi',
  };
  return switch (suono) {
    NotificationSettingsController.suonoSistema => base,
    NotificationSettingsController.suonoNessuno => '$base (silenzioso)',
    NotificationSettingsController.suonoSveglia =>
      '$base (suono della sveglia)',
    NotificationSettingsController.suonoSuoneria => '$base (suoneria)',
    _ => base,
  };
}

/// L'**id** del canale: `planner-<tipo>-<suono><vibrazione>` — per esempio
/// `planner-evento-0v` (suono di sistema, vibra) o `planner-evento-xm`
/// (silenzioso, senza vibrazione).
String idCanale(
  ReminderKind tipo, {
  required String suono,
  required bool vibra,
}) {
  final quale = switch (tipo) {
    ReminderKind.todo => 'todo',
    ReminderKind.riepilogo => 'riepilogo',
    _ => 'evento',
  };
  return 'planner-$quale-${codiceSuono(suono)}${vibra ? 'v' : 'm'}';
}

/// L'importanza di un tipo di avviso: gli eventi sono quelli che si muovono
/// nell'ora, le scadenze si spuntano, i riepiloghi si leggono.
int importanzaDi(ReminderKind tipo) => switch (tipo) {
      ReminderKind.todo => 3,
      ReminderKind.riepilogo => 2,
      _ => 4,
    };

/// La descrizione che si legge sotto il nome del canale, nelle impostazioni di
/// Android: dice a cosa serve, che è l'unica cosa che l'utente può vedere.
String descrizioneDi(ReminderKind tipo) => switch (tipo) {
      ReminderKind.todo => 'Le scadenze dei To do',
      ReminderKind.riepilogo => 'Le scadenze da confermare, la sera',
      _ => 'Gli eventi e le giornate intere',
    };

/// L'indirizzo `content://` di un suono di sistema, o `null` per «nessuno» e per
/// il suono di notifica predefinito (che è già quello del telefono).
///
/// Sono i tre suoni che Android ha **già**: non si aggiunge al repo nessun file
/// audio, e chi ha cambiato la suoneria del telefono se la ritrova qui.
String? suonoUriDi(String suono) => switch (suono) {
      NotificationSettingsController.suonoSveglia =>
        'content://settings/system/alarm_alert',
      NotificationSettingsController.suonoSuoneria =>
        'content://settings/system/ringtone',
      _ => null,
    };

/// Il canale da usare per un avviso **già calcolato**: il tipo dice l'importanza,
/// le impostazioni dicono suono e vibrazione, e l'avviso dice se deve restare
/// **muto** (un elemento su cui si è detto «non avvisarmi», o un avviso che
/// cade nelle ore silenziose: il pianificatore l'ha già deciso, vedi
/// `ScheduledReminder.loud`).
///
/// Un avviso muto ha bisogno del **canale silenzioso** del suo tipo: non si può
/// zittire la singola notifica, perché su Android 8+ la voce la decide il canale.
CanaleAvviso canalePerAvviso(
  ScheduledReminder avviso,
  NotificationSettingsController notifiche,
) {
  final vibra = switch (avviso.kind) {
    ReminderKind.todo => notifiche.vibraTodo,
    ReminderKind.riepilogo => false,
    _ => notifiche.vibraEventi,
  };
  // Il **riepilogo** è silenzioso per progetto (canale basso: è una cosa da
  // leggere, non da inseguire), quindi non segue la scelta del suono. Gli altri
  // diventano muti quando l'elemento lo chiede o quando l'avviso cade nelle ore
  // silenziose.
  final muto = avviso.kind == ReminderKind.riepilogo || !avviso.loud;
  return canalePer(
    avviso.kind,
    suono: muto ? NotificationSettingsController.suonoNessuno : notifiche.suono,
    vibra: muto ? false : vibra,
  );
}

/// Cosa si legge nel corpo dell'avviso.
///
/// Poche parole e sempre le stesse: l'ora la sa Android (l'avviso arriva quando
/// deve), il titolo dell'elemento è già il titolo della notifica. Ripetere «alle
/// 18:00» quando l'avviso arriva alle 17:45 sarebbe la cosa sbagliata — è
/// l'anticipo, non l'inizio.
String testoAvviso(ReminderKind tipo) => switch (tipo) {
      ReminderKind.todo => 'Scade oggi',
      ReminderKind.tuttoIlGiorno => 'Oggi',
      ReminderKind.riepilogo => 'Le scadenze da confermare',
      ReminderKind.evento => 'Tra poco',
    };

/// Cosa porta con sé la notifica: cosa si è toccato, **quando**, e con che
/// **canale**.
///
/// Perché l'istante: l'id di un avviso è stabile per (elemento, giorno,
/// anticipo), quindi **spostare** un evento di un'ora non cambia l'id — ma cambia
/// l'ora dell'allarme. Android di una notifica pianificata sa dire l'id e il
/// carico, non quando è fissata: mettendo qui l'istante, confrontare id e carico
/// dice anche se l'ora è quella giusta.
///
/// Perché il canale: su Android 8+ voce e vibrazione si scelgono **quando si
/// pianifica**, e non si cambiano più. Se il carico non lo portasse, cambiare il
/// suono o entrare nelle ore silenziose lascerebbe gli avvisi già fissati con il
/// canale vecchio — un avviso che suona di notte dopo che l'utente ha appena
/// messo il silenzio.
String caricoAvviso(
  ScheduledReminder avviso,
  NotificationSettingsController notifiche,
) =>
    '${_cosa(avviso)}@${avviso.when.millisecondsSinceEpoch}'
    '@${canalePerAvviso(avviso, notifiche).id}'
    '@${avviso.itemDate?.millisecondsSinceEpoch ?? ''}'
    '@${fnv1a64Hex([
      avviso.title,
      avviso.location,
      avviso.kind.name,
      avviso.hasTime,
      notifiche.blocco,
    ].join('\u0000').codeUnits)}@5';

String _cosa(ScheduledReminder avviso) => switch (avviso.kind) {
      ReminderKind.todo => 'todo:${avviso.itemId}',
      ReminderKind.riepilogo => 'riepilogo',
      _ => 'evento:${avviso.itemId}',
    };

/// Il canale da usare per un tipo, con il suono e la vibrazione scelti.
CanaleAvviso canalePer(
  ReminderKind tipo, {
  required String suono,
  required bool vibra,
}) {
  final suona = suono != NotificationSettingsController.suonoNessuno;
  return CanaleAvviso(
    id: idCanale(tipo, suono: suono, vibra: vibra),
    nome: nomeCanale(tipo, suono),
    descrizione: descrizioneDi(tipo),
    importanza: importanzaDi(tipo),
    suona: suona,
    vibra: vibra,
    suonoUri: suonoUriDi(suono),
  );
}

/// I canali che gli avvisi useranno con queste impostazioni: eventi, todo e
/// riepiloghi. Serve ad **assicurarli** tutti e tre, così nelle impostazioni di
/// Android compaiono anche prima che il primo avviso venga pianificato.
///
/// Un avviso può aver bisogno di un canale che non è in questo elenco (un
/// elemento che deve restare **muto** mentre il tipo suona): quel canale lo crea
/// il sink quando pianifica, perché la creazione è idempotente.
List<CanaleAvviso> canaliNecessari(NotificationSettingsController notifiche) =>
    [
      canalePer(
        ReminderKind.evento,
        suono: notifiche.suono,
        vibra: notifiche.vibraEventi,
      ),
      canalePer(
        ReminderKind.todo,
        suono: notifiche.suono,
        vibra: notifiche.vibraTodo,
      ),
      canalePer(
        ReminderKind.riepilogo,
        suono: NotificationSettingsController.suonoNessuno,
        vibra: false,
      ),
    ];
