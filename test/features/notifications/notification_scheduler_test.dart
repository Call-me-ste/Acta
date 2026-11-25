import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/database/occurrence_commands.dart';
import 'package:planner/features/notifications/domain/reminder_planner.dart';
import 'package:planner/features/notifications/domain/riepilogo_planner.dart';
import 'package:planner/features/notifications/notification_scheduler.dart';
import 'package:planner/features/notifications/notification_actions.dart';
import 'package:planner/features/notifications/notification_settings_controller.dart';

import '../../support/fake_notification_sink.dart';

/// La **riconciliazione**: quello che è pianificato nel sistema deve combaciare
/// con quello che ci deve essere.
///
/// È la parte che, sbagliata, si vede in due modi opposti: un avviso che arriva
/// due volte (perché si pianifica senza annullare il vecchio) o un avviso che non
/// arriva più (perché si è annullato quello giusto). Si prova con il sink finto:
/// gli avvisi sono una mappa, e si legge esattamente cosa c'è.
void main() {
  late DatabaseService db;
  late NotificationSettingsController notifiche;
  late FakeNotificationSink sink;
  late NotificationScheduler scheduler;

  // Riferimento: giovedì 24 settembre 2026, ore 12:00.
  var adesso = DateTime(2026, 9, 24, 12);

  setUp(() async {
    adesso = DateTime(2026, 9, 24, 12);
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    notifiche = NotificationSettingsController(db.settings)..load();
    notifiche.setAttive(true);
    sink = FakeNotificationSink();
    scheduler = NotificationScheduler(
      db,
      notifiche,
      sink,
      adesso: () => adesso,
    );
  });

  tearDown(() {
    scheduler.dispose();
    db.close();
  });

  void evento(
    String id, {
    String titolo = 'Dentista',
    required DateTime inizio,
    Duration durata = const Duration(hours: 1),
    bool tuttoIlGiorno = false,
    String regola = '',
    bool aggiorna = false,
  }) {
    final riga = {
      'id': id,
      'title': titolo,
      'start_time': inizio.millisecondsSinceEpoch,
      'end_time': inizio.add(durata).millisecondsSinceEpoch,
      'all_day': tuttoIlGiorno ? 1 : 0,
      'recurrence_rule': regola,
      'updated_at': inizio.millisecondsSinceEpoch,
    };
    aggiorna ? db.updateEvent(riga) : db.insertEvent(riga);
  }

  void todo(String id, {String titolo = 'Spesa', DateTime? scade}) {
    db.insertTodo({
      'id': id,
      'title': titolo,
      'due_date': scade?.millisecondsSinceEpoch,
      'updated_at': adesso.millisecondsSinceEpoch,
    });
  }

  test('un rinvio resta pianificato quando si riapre Planner', () async {
    final inizio = adesso.add(const Duration(hours: 1));
    evento('e1', inizio: inizio);
    await scheduler.riconcilia();
    final payload = sink.carichi.values.single;
    final target = NotificationTarget.parse(payload)!;
    adesso = sink.avvisi.values.single.when.add(const Duration(seconds: 1));
    final azioni = NotificationActions(db);
    expect(azioni.rimanda(target, payload, adesso, notifiche), isTrue);

    final nuovo =
        NotificationScheduler(db, notifiche, sink, adesso: () => adesso);
    await nuovo.riconcilia();
    final rinvio = sink.avvisi.values.single;
    expect(idDiRinvio(rinvio.id), isTrue);
    expect(rinvio.when, adesso.add(const Duration(minutes: 10)));
    expect(rinvio.itemDate, inizio);
    adesso = rinvio.when.add(const Duration(seconds: 5));
    await nuovo.riconcilia();
    expect(sink.avvisi.keys, contains(rinvio.id));

    // Dopo la consegna il sistema toglie la richiesta e il rinvio non rinasce.
    await sink.annulla(rinvio.id);
    await nuovo.riconcilia();
    expect(sink.avvisi, isEmpty);
  });

  test('la notifica completa un To do singolo una sola volta', () {
    final giorno = DateTime(2026, 9, 24);
    todo('t1', scade: giorno);
    final target = NotificationTarget('todo', 't1', giorno);
    final azioni = NotificationActions(db);
    expect(azioni.completa(target), isTrue);
    expect(azioni.completa(target), isFalse);
    expect(db.getTodos().single['completed'], 1);
    expect(db.outbox.pending().single['entity_type'], 'todo');
    expect(db.meta.get(notificationCompletionClock), isNotNull);
  });

  test('la notifica completa solo la data del To do ricorrente', () {
    final giorno = DateTime(2026, 9, 24);
    db.insertTodo({
      'id': 'ricorrente',
      'title': 'Ripasso',
      'due_date': giorno.millisecondsSinceEpoch,
      'recurrence_rule': 'FREQ=DAILY',
    });
    final target = NotificationTarget('todo', 'ricorrente', giorno);
    final azioni = NotificationActions(db);
    expect(azioni.completa(target), isTrue);
    expect(azioni.completa(target), isFalse);
    expect(db.getTodos().single['completed'], 0);
    expect(db.occurrences.isDone('ricorrente', giorno), isTrue);
    expect(db.occurrences.isDone('ricorrente', DateTime(2026, 9, 25)), isFalse);
    expect(db.outbox.pending().single['entity_type'], 'occurrence_override');
  });

  test('un evento spostato tiene lo stesso id ma suona all\'ora nuova',
      () async {
    evento('e1', inizio: adesso.add(const Duration(hours: 3)));
    await scheduler.riconcilia();
    expect(sink.avvisi, hasLength(1), reason: 'un evento, un avviso');
    final id = sink.avvisi.keys.single;
    final quandoPrima = sink.avvisi[id]!.when;
    final pianificazioni = sink.canali.length;

    // L'evento si sposta di un'ora: l'id resta **lo stesso** (è stabile per
    // elemento, giorno e anticipo — ed è quello che impedisce i doppioni), ma
    // l'allarme va rifatto, se no suona all'ora vecchia.
    evento('e1', inizio: adesso.add(const Duration(hours: 4)), aggiorna: true);
    await scheduler.riconcilia();

    expect(sink.avvisi, hasLength(1), reason: 'sostituito, non duplicato');
    expect(sink.avvisi.keys.single, id);
    expect(sink.avvisi[id]!.when, isNot(quandoPrima),
        reason: 'l\'ora nuova è quella che si sente');
    expect(sink.canali.length, pianificazioni + 1,
        reason: 'ripianificato: la riconciliazione guarda anche il carico');
  });

  test('un\'occorrenza confermata non avvisa più', () async {
    evento('e1', inizio: adesso.add(const Duration(hours: 3)));
    await scheduler.riconcilia();
    expect(sink.avvisi, hasLength(1));

    db.markOccurrenceDone(
      itemId: 'e1',
      day: DateTime(2026, 9, 24),
      operationId: 'op-1',
    );
    await scheduler.riconcilia();

    expect(sink.avvisi, isEmpty,
        reason: 'confermata: l\'avviso è stato annullato');
  });

  test('nelle ore silenziose l\'avviso c\'è, ma sul canale silenzioso',
      () async {
    notifiche.setSilenzio(da: 17 * 60, a: 19 * 60);
    evento('e1', inizio: DateTime(2026, 9, 24, 18));

    await scheduler.riconcilia();

    expect(sink.avvisi, hasLength(1), reason: 'muto ma consegnato');
    expect(sink.avvisi.values.single.quiet, isTrue);
    expect(sink.canali.single, 'planner-evento-xm',
        reason:
            'non si può zittire la singola notifica: si usa il canale muto');
  });

  test('un tipo spento non pianifica niente', () async {
    notifiche.setEvento(false);
    evento('e1', inizio: adesso.add(const Duration(hours: 3)));
    todo('t1', scade: adesso.add(const Duration(days: 2)));

    await scheduler.riconcilia();

    expect(sink.avvisi, hasLength(1), reason: 'solo il todo');
    expect(sink.avvisi.values.single.kind.name, 'todo');
  });

  test('spegnere l\'interruttore generale annulla quello che c\'è', () async {
    evento('e1', inizio: adesso.add(const Duration(hours: 3)));
    await scheduler.riconcilia();
    expect(sink.avvisi, isNotEmpty);

    notifiche.setAttive(false);
    await scheduler.riconcilia();

    expect(sink.avvisi, isEmpty,
        reason: 'spegnere le notifiche spegne anche quelle già pianificate');
  });

  test('cambiare il suono ripianifica quello che è già fissato', () async {
    evento('e1', inizio: adesso.add(const Duration(hours: 3)));
    await scheduler.riconcilia();
    final pianificazioni = sink.canali.length;

    notifiche.setSuono(NotificationSettingsController.suonoSveglia);
    await scheduler.riconcilia();

    expect(sink.canali.length, pianificazioni + 1,
        reason:
            'canale diverso: l\'avviso va rifatto, se no suona con la voce vecchia');
    expect(sink.canali.last, 'planner-evento-1v');
  });

  test('entrare nelle ore silenziose ripianifica l\'avviso sul canale muto',
      () async {
    evento('e1', inizio: DateTime(2026, 9, 24, 18));
    await scheduler.riconcilia();
    expect(sink.canali.single, 'planner-evento-0v');

    // 17:45 è dentro 17:00-19:00: l'avviso c'è già, e deve diventare muto.
    notifiche.setSilenzio(da: 17 * 60, a: 19 * 60);
    await scheduler.riconcilia();

    expect(sink.canali.last, 'planner-evento-xm',
        reason:
            'un avviso che suona di notte dopo che l\'utente ha messo il silenzio');
    expect(sink.avvisi.values.single.quiet, isTrue);
  });

  test('chi c\'è già non si tocca', () async {
    evento('e1', inizio: adesso.add(const Duration(hours: 3)));
    await scheduler.riconcilia();
    final pianificazioni = sink.canali.length;

    await scheduler.riconcilia();
    await scheduler.riconcilia();

    expect(sink.canali.length, pianificazioni,
        reason:
            'tre giri, una pianificazione: id **e carico** uguali, niente da fare');
  });

  test(
      'il riepilogo arriva per le prossime sere, ma solo se c\'è da confermare',
      () async {
    notifiche.setRiepilogo(true);
    // Niente da confermare: solo un evento futuro.
    evento('e1', inizio: adesso.add(const Duration(hours: 3)));
    await scheduler.riconcilia();
    expect(
      sink.avvisi.values.where((a) => a.kind.name == 'riepilogo'),
      isEmpty,
      reason: 'un riepilogo che dice «niente da fare» è rumore',
    );

    // Un todo scaduto ieri: da stasera il riepilogo ha senso.
    todo('t1', scade: adesso.subtract(const Duration(days: 1)));
    await scheduler.riconcilia();

    final riepiloghi =
        sink.avvisi.values.where((a) => a.kind.name == 'riepilogo').toList();
    expect(riepiloghi, hasLength(7), reason: 'le prossime sette sere');
    expect(riepiloghi.first.when.hour, 20, reason: 'alle 20:00');
    expect(
      riepiloghi.map((a) => a.id),
      everyElement(isNotNull),
      reason: 'id stabili: ricalcolare sostituisce, non aggiunge',
    );

    await scheduler.riconcilia();
    expect(
      sink.avvisi.values.where((a) => a.kind.name == 'riepilogo'),
      hasLength(7),
      reason: 'un secondo giro non ne aggiunge altri',
    );
  });

  test('due modifiche di fila fanno un giro solo', () async {
    scheduler = NotificationScheduler(
      db,
      notifiche,
      sink,
      adesso: () => adesso,
      debounce: const Duration(milliseconds: 40),
    );
    evento('e1', inizio: adesso.add(const Duration(hours: 3)));

    scheduler.programma();
    scheduler.programma();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(sink.preparazioni, 1,
        reason: 'il debounce aspetta la fine delle scritture');
    expect(sink.avvisi, hasLength(1));
  });

  test('gli id degli avvisi sono quelli del pianificatore', () async {
    final inizio = adesso.add(const Duration(hours: 3));
    evento('e1', inizio: inizio);

    await scheduler.riconcilia();

    expect(
      sink.avvisi.keys.single,
      reminderIdFor('e1', DateTime(2026, 9, 24), 15),
      reason:
          'stesso id fra due giri e fra due avvii: è quello che evita i doppioni',
    );
  });

  test('il riepilogo ha l\'id stabile della sua sera', () async {
    notifiche.setRiepilogo(true);
    todo('t1', scade: adesso.subtract(const Duration(days: 1)));

    await scheduler.riconcilia();

    expect(
      sink.avvisi.containsKey(
        reminderIdFor(riepilogoItemId, DateTime(2026, 9, 24, 20), 0),
      ),
      isTrue,
    );
  });
}
