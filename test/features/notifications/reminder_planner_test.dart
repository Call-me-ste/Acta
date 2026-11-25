import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/domain/event_occurrence.dart';
import 'package:planner/features/notifications/domain/reminder_plan.dart';
import 'package:planner/features/notifications/domain/reminder_planner.dart';
import 'package:planner/features/todos/domain/todo.dart';

/// Il pianificatore dei promemoria: "quali avvisi nascono, quando, e con che
/// voce". Si prova con date invece che col telefono: la risposta e' esatta, e
/// un errore qui e' un promemoria che non arriva o che arriva due volte.
void main() {
  // Riferimento: giovedi' 17 settembre 2026, mezzogiorno.
  final adesso = DateTime(2026, 9, 17, 12);

  Event evento({
    String id = 'e1',
    String titolo = 'Dentista',
    DateTime? inizio,
    DateTime? fine,
    bool tuttoIlGiorno = false,
    List<int>? anticipi,
    bool? suono,
  }) {
    final start = inizio ?? DateTime(2026, 9, 17, 18);
    return Event(
      id: id,
      title: titolo,
      start: start,
      end: fine ?? start.add(const Duration(hours: 1)),
      allDay: tuttoIlGiorno,
      reminderLeads: anticipi,
      reminderSound: suono,
    );
  }

  EventOccurrence occorrenza(Event event, [DateTime? giorno]) =>
      EventOccurrence(
        event: event,
        date: giorno ??
            DateTime(event.start.year, event.start.month, event.start.day),
        start: event.start,
        end: event.end,
      );

  ReminderInputs inputs({
    List<EventOccurrence> eventi = const [],
    List<Todo> todo = const [],
    Set<String> fatti = const {},
    int anticipoEventi = 15,
    int anticipoTodo = 0,
    int oraTodo = 9,
    int oraTuttoIlGiorno = 8,
    bool suono = true,
    Duration finestra = const Duration(days: 30),
    int tetto = 64,
  }) {
    return ReminderInputs(
      now: adesso,
      occurrences: eventi,
      todos: todo,
      doneOccurrences: fatti,
      eventLead: anticipoEventi,
      todoLead: anticipoTodo,
      todoMinuteOfDay: oraTodo * 60,
      allDayMinuteOfDay: oraTuttoIlGiorno * 60,
      soundDefault: suono,
      window: finestra,
      maxReminders: tetto,
    );
  }

  test('i To do ricorrenti usano l’orario della singola occorrenza', () {
    final ancora = DateTime(2026, 9, 17);
    final piano = planReminders(inputs(
      todo: [
        Todo(
          id: 'ricorrente',
          title: 'Ripasso',
          dueDate: ancora,
          startMinutes: 11 * 60 + 30,
          recurrenceRule: 'FREQ=DAILY',
        ),
      ],
      fatti: {occurrenceKey('ricorrente', ancora)},
      finestra: const Duration(days: 3),
    ));
    expect(piano.map((r) => r.when), [
      DateTime(2026, 9, 18, 11, 30),
      DateTime(2026, 9, 19, 11, 30),
      DateTime(2026, 9, 20, 11, 30),
    ]);
  });

  group('eventi', () {
    test('avvisa con l\'anticipo delle impostazioni', () {
      final piano = planReminders(
        inputs(eventi: [occorrenza(evento())]),
      );
      expect(piano, hasLength(1));
      expect(piano.single.when, DateTime(2026, 9, 17, 17, 45));
      expect(piano.single.kind, ReminderKind.evento);
      expect(piano.single.title, 'Dentista');
    });

    test('piu\' anticipi danno piu\' avvisi, con id diversi', () {
      final piano = planReminders(
        inputs(eventi: [
          occorrenza(evento(anticipi: const [15, 60]))
        ]),
      );
      expect(piano, hasLength(2));
      expect(piano.map((r) => r.when).toList(), [
        DateTime(2026, 9, 17, 17),
        DateTime(2026, 9, 17, 17, 45),
      ]);
      expect(piano[0].id, isNot(piano[1].id));
    });

    test('elenco vuoto vuol dire «nessun promemoria»', () {
      final piano = planReminders(
        inputs(eventi: [occorrenza(evento(anticipi: const []))]),
      );
      expect(piano, isEmpty);
    });

    test('un evento tutto il giorno avvisa la mattina del giorno stesso', () {
      final tuttoIlGiorno = evento(
        tuttoIlGiorno: true,
        inizio: DateTime(2026, 9, 18),
        fine: DateTime(2026, 9, 18, 23, 59),
      );
      final piano = planReminders(
        inputs(eventi: [occorrenza(tuttoIlGiorno, DateTime(2026, 9, 18))]),
      );
      expect(piano.single.when, DateTime(2026, 9, 18, 8));
      expect(piano.single.kind, ReminderKind.tuttoIlGiorno);
    });

    test('nessun promemoria vale anche per un evento senza orario', () {
      final tuttoIlGiorno = evento(
        tuttoIlGiorno: true,
        inizio: DateTime(2026, 9, 18),
        anticipi: const [],
      );
      expect(
          planReminders(inputs(eventi: [occorrenza(tuttoIlGiorno)])), isEmpty);
    });

    test('un avviso gia\' passato non si pianifica', () {
      final passato = evento(inizio: DateTime(2026, 9, 17, 12, 10));
      expect(planReminders(inputs(eventi: [occorrenza(passato)])), isEmpty);
    });

    test('fuori dalla finestra non si pianifica', () {
      final lontano = evento(inizio: DateTime(2026, 11, 1, 18));
      final piano = planReminders(
        inputs(eventi: [occorrenza(lontano)]),
      );
      expect(piano, isEmpty, reason: 'la finestra e\' di trenta giorni');
    });

    test('un\'occorrenza confermata non avvisa piu\'', () {
      final e = evento();
      final piano = planReminders(
        inputs(
          eventi: [occorrenza(e)],
          fatti: {occurrenceKey(e.id, DateTime(2026, 9, 17))},
        ),
      );
      expect(piano, isEmpty);
    });
  });

  group('todo', () {
    test('avvisa all\'ora della scadenza meno l\'anticipo', () {
      final spesa = Todo(
        id: 't1',
        title: 'Spesa',
        dueDate: DateTime(2026, 9, 18),
        reminderLeads: const [60],
      );
      final piano = planReminders(inputs(todo: [spesa]));
      expect(piano.single.when, DateTime(2026, 9, 18, 8));
      expect(piano.single.kind, ReminderKind.todo);
    });

    test('un todo senza scadenza non avvisa', () {
      const senzaScadenza = Todo(id: 't2', title: 'Prima o poi');
      expect(planReminders(inputs(todo: [senzaScadenza])), isEmpty);
    });

    test('un todo gia\' fatto non avvisa', () {
      final fatto = Todo(
        id: 't3',
        title: 'Fatto',
        dueDate: DateTime(2026, 9, 18),
        completed: true,
      );
      expect(planReminders(inputs(todo: [fatto])), isEmpty);
    });
  });

  group('ore silenziose, ordine e tetto', () {
    test('in ore silenziose l\'avviso resta ma non suona', () {
      final e = evento(inizio: DateTime(2026, 9, 17, 23, 30));
      final piano = planReminders(
        inputs(eventi: [occorrenza(e)], anticipoEventi: 0),
        quiet: (start: 22 * 60, end: 7 * 60),
      );
      expect(piano.single.quiet, isTrue);
      expect(piano.single.sound, isTrue,
          reason: 'il suono dell\'elemento c\'e\'');
      expect(piano.single.loud, isFalse, reason: 'ma ora tace');
    });

    test('fuori dalle ore silenziose suona', () {
      final piano = planReminders(
        inputs(eventi: [occorrenza(evento())]),
        quiet: (start: 22 * 60, end: 7 * 60),
      );
      expect(piano.single.quiet, isFalse);
      expect(piano.single.loud, isTrue);
    });

    test('il suono dell\'elemento vince su quello delle impostazioni', () {
      final muto = evento(suono: false);
      final piano = planReminders(
        inputs(eventi: [occorrenza(muto)], suono: true),
      );
      expect(piano.single.sound, isFalse);
      expect(piano.single.loud, isFalse);
    });

    test('si pianifica in ordine di ora e non oltre il tetto', () {
      final eventi = [
        for (var ora = 13; ora < 25; ora++)
          occorrenza(
            evento(
              id: 'e$ora',
              inizio: DateTime(2026, 9, 17, ora % 24, 30),
            ),
          ),
      ];
      final piano = planReminders(
        inputs(eventi: eventi, anticipoEventi: 0, tetto: 5),
      );
      expect(piano, hasLength(5));
      for (var i = 1; i < piano.length; i++) {
        expect(
          piano[i].when.isBefore(piano[i - 1].when),
          isFalse,
          reason: 'l\'ordine deve essere per ora',
        );
      }
    });
  });

  group('identificativo', () {
    test('e\' stabile fra due calcoli', () {
      final e = evento();
      final primo = planReminders(inputs(eventi: [occorrenza(e)])).single.id;
      final secondo = planReminders(inputs(eventi: [occorrenza(e)])).single.id;
      expect(primo, secondo,
          reason: 'se cambiasse, si duplicherebbe l\'avviso');
      expect(primo, greaterThan(0), reason: 'Android vuole un int positivo');
    });

    test('e\' diverso per un anticipo diverso', () {
      final giorno = DateTime(2026, 9, 17);
      expect(
        reminderIdFor('e1', giorno, 15),
        isNot(reminderIdFor('e1', giorno, 60)),
      );
      expect(
        reminderIdFor('e1', giorno, 15),
        isNot(reminderIdFor('e2', giorno, 15)),
      );
    });
  });
}
