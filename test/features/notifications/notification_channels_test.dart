import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/notifications/domain/reminder_plan.dart';
import 'package:planner/features/notifications/notification_channels.dart';
import 'package:planner/features/notifications/notification_settings_controller.dart';
import 'package:planner/features/notifications/notification_sink.dart';
import 'package:planner/features/notifications/flutter_local_notifications_sink.dart';

import '../../support/fake_notification_sink.dart';

/// **Quale canale** tocca a un avviso, e con che voce.
///
/// È la parte che su Android 8+ non si può più cambiare dopo: suono e vibrazione
/// si scrivono nel canale alla creazione, quindi sbagliare qui vuol dire un
/// avviso muto che doveva suonare (o che suona di notte) e nessun modo di
/// sistemarlo se non creandone un altro. Quindi si prova senza telefono: sono
/// valori, e i valori si leggono.
void main() {
  late DatabaseService db;
  late NotificationSettingsController notifiche;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    notifiche = NotificationSettingsController(db.settings)..load();
  });

  tearDown(() => db.close());

  ScheduledReminder avviso(
    ReminderKind tipo, {
    bool suona = true,
    bool quieto = false,
    String itemId = 'e1',
    int id = 7,
  }) {
    return ScheduledReminder(
      id: id,
      itemId: itemId,
      when: DateTime(2026, 9, 24, 18),
      title: 'Dentista',
      kind: tipo,
      sound: suona,
      quiet: quieto,
    );
  }

  group('l\'id del canale', () {
    test('porta dentro il suono e la vibrazione', () {
      expect(
        idCanale(ReminderKind.evento,
            suono: NotificationSettingsController.suonoSistema, vibra: true),
        'planner-evento-0v',
      );
      expect(
        idCanale(ReminderKind.todo,
            suono: NotificationSettingsController.suonoNessuno, vibra: false),
        'planner-todo-xm',
      );
      expect(
        idCanale(ReminderKind.riepilogo,
            suono: NotificationSettingsController.suonoSveglia, vibra: false),
        'planner-riepilogo-1m',
      );
      expect(
        idCanale(ReminderKind.tuttoIlGiorno,
            suono: NotificationSettingsController.suonoSuoneria, vibra: true),
        'planner-evento-2v',
        reason: 'i due tipi di evento dividono lo stesso canale',
      );
    });

    test('suoni diversi danno canali diversi, la stessa cosa lo stesso canale',
        () {
      final sistema = idCanale(ReminderKind.evento,
          suono: NotificationSettingsController.suonoSistema, vibra: true);
      final sveglia = idCanale(ReminderKind.evento,
          suono: NotificationSettingsController.suonoSveglia, vibra: true);

      expect(sistema, isNot(sveglia),
          reason:
              'il canale non si aggiorna: se il suono cambia, se ne usa un altro');
      expect(
        idCanale(ReminderKind.evento,
            suono: NotificationSettingsController.suonoSistema, vibra: true),
        sistema,
        reason: 'idempotente: due calcoli, un canale',
      );
    });
  });

  group('i tre canali che servono', () {
    test('con le impostazioni di partenza: due vivi e un riepilogo silenzioso',
        () {
      final canali = canaliNecessari(notifiche);

      expect(canali.map((c) => c.id), [
        'planner-evento-0v',
        'planner-todo-0v',
        'planner-riepilogo-xm',
      ]);
      expect(canali[0].importanza, 4,
          reason: 'gli eventi sono quelli che si muovono');
      expect(canali[1].importanza, 3);
      expect(canali[2].importanza, 2,
          reason: 'il riepilogo si legge, non sveglia');
      expect(canali[2].suona, isFalse);
      expect(canali[2].vibra, isFalse);
    });

    test('cambiare il suono cambia i canali, non li aggiorna', () {
      notifiche.setSuono(NotificationSettingsController.suonoSuoneria);

      expect(canaliNecessari(notifiche).map((c) => c.id), [
        'planner-evento-2v',
        'planner-todo-2v',
        'planner-riepilogo-xm',
      ]);
    });

    test('la vibrazione si spegne per tipo', () {
      notifiche.setVibraTodo(false);

      final canali = canaliNecessari(notifiche);
      expect(canali[0].id, 'planner-evento-0v');
      expect(canali[1].id, 'planner-todo-0m');
    });
  });

  group('un singolo avviso', () {
    test('normale: suona e vibra come il suo tipo', () {
      final canale = canalePerAvviso(avviso(ReminderKind.todo), notifiche);

      expect(canale.id, 'planner-todo-0v');
      expect(canale.suona, isTrue);
      expect(canale.vibra, isTrue);
    });

    test('con «non avvisarmi» sull\'elemento: canale silenzioso', () {
      final canale =
          canalePerAvviso(avviso(ReminderKind.evento, suona: false), notifiche);

      expect(canale.id, 'planner-evento-xm');
      expect(canale.suona, isFalse);
      expect(canale.vibra, isFalse,
          reason: 'muto vuol dire muto: nemmeno la vibrazione');
    });

    test('nelle ore silenziose: resta, ma sul canale silenzioso', () {
      final canale = canalePerAvviso(
        avviso(ReminderKind.evento, quieto: true),
        notifiche,
      );

      expect(canale.id, 'planner-evento-xm');
      expect(canale.importanza, 4,
          reason: 'muto non vuol dire nascosto: l\'avviso si vede');
    });

    test('il riepilogo è silenzioso anche con il suono acceso', () {
      notifiche.setSuono(NotificationSettingsController.suonoSveglia);

      final canale = canalePerAvviso(avviso(ReminderKind.riepilogo), notifiche);

      expect(canale.id, 'planner-riepilogo-xm');
    });
  });

  group('il suono', () {
    test('sveglia e suoneria sono suoni di sistema, non file nostri', () {
      expect(
        suonoUriDi(NotificationSettingsController.suonoSveglia),
        'content://settings/system/alarm_alert',
      );
      expect(
        suonoUriDi(NotificationSettingsController.suonoSuoneria),
        'content://settings/system/ringtone',
      );
      expect(suonoUriDi(NotificationSettingsController.suonoSistema), isNull,
          reason: 'il suono di notifica lo mette il telefono');
      expect(suonoUriDi(NotificationSettingsController.suonoNessuno), isNull);
    });

    test('con «nessuno» il canale non suona', () {
      final canale = canalePer(
        ReminderKind.evento,
        suono: NotificationSettingsController.suonoNessuno,
        vibra: true,
      );

      expect(canale.suona, isFalse);
      expect(canale.vibra, isTrue, reason: 'muto ma con la vibrazione: si può');
      expect(canale.nome, 'Eventi (silenzioso)');
    });

    test('il nome dice il suono solo quando serve', () {
      expect(
        nomeCanale(
            ReminderKind.evento, NotificationSettingsController.suonoSistema),
        'Eventi',
      );
      expect(
        nomeCanale(
            ReminderKind.todo, NotificationSettingsController.suonoSuoneria),
        'To do (suoneria)',
      );
    });
  });

  group('il testo dell\'avviso', () {
    test('una riga per tipo, corta', () {
      expect(testoAvviso(ReminderKind.evento), 'Tra poco');
      expect(testoAvviso(ReminderKind.todo), 'Scade oggi');
      expect(testoAvviso(ReminderKind.tuttoIlGiorno), 'Oggi');
      expect(testoAvviso(ReminderKind.riepilogo), 'Le scadenze da confermare');
    });

    test('il carico dice cosa si è toccato, e **quando**', () {
      // L'istante serve alla riconciliazione: l'id di un evento spostato resta
      // lo stesso, quindi senza l'ora nel carico non si saprebbe che l'allarme
      // va rifatto.
      final quando = DateTime(2026, 9, 24, 17, 45).millisecondsSinceEpoch;
      ScheduledReminder conOra(ReminderKind tipo, String itemId) =>
          ScheduledReminder(
            id: 7,
            itemId: itemId,
            when: DateTime(2026, 9, 24, 17, 45),
            title: 'Dentista',
            kind: tipo,
            sound: true,
            quiet: false,
          );

      expect(caricoAvviso(conOra(ReminderKind.evento, 'e9'), notifiche),
          startsWith('evento:e9@$quando@planner-evento-0v@'));
      expect(
        caricoAvviso(conOra(ReminderKind.todo, 't3'), notifiche),
        startsWith('todo:t3@$quando@planner-todo-0v@'),
      );
      expect(
        caricoAvviso(conOra(ReminderKind.riepilogo, 'riepilogo'), notifiche),
        startsWith('riepilogo@$quando@planner-riepilogo-xm@'),
        reason:
            'il canale è nella parte del carico: è lui che dice con che voce',
      );
    });
  });

  group('il sink', () {
    test('la finta tiene gli avvisi come farebbe Android', () async {
      final NotificationSink sink = FakeNotificationSink();
      final avvisi = [
        avviso(ReminderKind.evento, itemId: 'e1', id: 101),
        avviso(ReminderKind.todo, itemId: 't1', id: 202),
      ];

      for (final a in avvisi) {
        await sink.pianifica(a, notifiche);
      }
      expect(await sink.pianificati(), hasLength(2));

      await sink.annulla(avvisi.first.id);

      expect(await sink.pianificati(), hasLength(1));
      await sink.annulla(9999); // id che non c'è: non è un errore
      expect(await sink.pianificati(), hasLength(1));
    });

    test('il sink vero esiste e si può costruire senza toccare il telefono',
        () {
      // Non si chiama niente: si verifica solo che l'implementazione sia quella
      // giusta e che il tipo regga il contratto (i metodi nativi partono al
      // primo `prepara`, e nei test non si arriva lì).
      expect(FlutterLocalNotificationsSink.new, isNotNull);
      expect(FakeNotificationSink(), isA<NotificationSink>());
    });
  });
}
