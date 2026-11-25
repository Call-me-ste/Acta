import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/recurrence/domain/recurrence_expansion.dart';
import 'package:planner/features/recurrence/domain/recurrence_label.dart';
import 'package:planner/features/recurrence/domain/recurrence_rule.dart';

/// Il motore delle ricorrenze.
///
/// Il difetto che questa suite deve impedire è quello della v2: un item
/// ricorrente che compare in **ogni** giorno invece che nel suo. Per questo i
/// test contano le occorrenze invece di limitarsi a verificarne l'esistenza.
void main() {
  RecurrenceRule? parse(String? raw) => RecurrenceRule.tryParse(raw);

  group('regola', () {
    test('fa round trip della stringa', () {
      final rule = parse('FREQ=WEEKLY;BYDAY=MO,WE,FR;UNTIL=2026-12-31');

      expect(rule, isNotNull);
      expect(rule!.frequency, RecurrenceFrequency.weekly);
      expect(rule.weekdays, {1, 3, 5});
      expect(rule.until, DateTime(2026, 12, 31));
      expect(
          rule.toRuleString(), 'FREQ=WEEKLY;BYDAY=MO,WE,FR;UNTIL=2026-12-31');
    });

    test('una stringa vuota o illeggibile diventa "nessuna ricorrenza"', () {
      // Un dato remoto storto non deve impedire l'apertura di una lista.
      expect(parse(''), isNull);
      expect(parse(null), isNull);
      expect(parse('BYDAY=MO'), isNull);
      expect(parse('FREQ=OGNI_TANTO'), isNull);
    });
  });

  group('etichetta', () {
    final anchor = DateTime(2026, 9, 14); // un lunedì

    test('deriva dalla regola, in italiano', () {
      expect(
          recurrenceLabel(parse('FREQ=DAILY'), anchor: anchor), 'ogni giorno');
      expect(
        recurrenceLabel(parse('FREQ=WEEKLY'), anchor: anchor),
        'ogni settimana',
      );
      expect(
        recurrenceLabel(parse('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'),
            anchor: anchor),
        'ogni lun-ven',
      );
      expect(
        recurrenceLabel(parse('FREQ=WEEKLY;BYDAY=MO'), anchor: anchor),
        'ogni lunedì',
      );
      expect(
        recurrenceLabel(parse('FREQ=WEEKLY;BYDAY=MO,WE,FR'), anchor: anchor),
        'ogni lun, mer, ven',
      );
      expect(
        recurrenceLabel(parse('FREQ=MONTHLY'), anchor: anchor),
        'ogni mese il 14',
      );
      expect(
          recurrenceLabel(parse('FREQ=YEARLY'), anchor: anchor), 'ogni anno');
      expect(recurrenceLabel(null, anchor: anchor), '');
    });

    test('dice anche quando finisce', () {
      expect(
        recurrenceLabel(
          parse('FREQ=DAILY;UNTIL=2026-12-31'),
          anchor: anchor,
        ),
        'ogni giorno fino al 31/12/2026',
      );
    });
  });

  group('espansione', () {
    test('ogni giorno: una data per giorno, e sono esattamente i giorni', () {
      final dates = expandOccurrences(
        parse('FREQ=DAILY')!,
        start: DateTime(2026, 9, 13, 9),
        rangeStart: DateTime(2026, 9, 13),
        rangeEnd: DateTime(2026, 9, 15),
      );

      // Tre giorni, tre occorrenze: non tre sezioni per tre giorni.
      expect(dates, [
        DateTime(2026, 9, 13),
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 15),
      ]);
    });

    test('una regola nata anni prima non consuma il tetto per arrivare a oggi',
        () {
      // È il modo in cui una finestra grande verrebbe troncata in silenzio se
      // l'espansione partisse sempre dalla data di nascita.
      final dates = expandOccurrences(
        parse('FREQ=DAILY')!,
        start: DateTime(2019, 1, 1),
        rangeStart: DateTime(2026, 9, 13),
        rangeEnd: DateTime(2026, 9, 15),
      );

      expect(dates, hasLength(3));
      expect(dates.first, DateTime(2026, 9, 13));
    });

    test('lun-ven: cinque occorrenze, mai sabato o domenica', () {
      final dates = expandOccurrences(
        parse('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR')!,
        start: DateTime(2026, 9, 14),
        rangeStart: DateTime(2026, 9, 14),
        rangeEnd: DateTime(2026, 9, 20),
      );

      expect(dates, hasLength(5));
      expect(dates.any((date) => date.weekday >= 6), isFalse);
    });

    test('giorni scelti: lun, mer, ven', () {
      final dates = expandOccurrences(
        parse('FREQ=WEEKLY;BYDAY=MO,WE,FR')!,
        start: DateTime(2026, 9, 14),
        rangeStart: DateTime(2026, 9, 14),
        rangeEnd: DateTime(2026, 9, 20),
      );

      expect(dates.map((date) => date.day), [14, 16, 18]);
    });

    test('ogni settimana senza giorni espliciti: lo stesso giorno', () {
      final dates = expandOccurrences(
        parse('FREQ=WEEKLY')!,
        start: DateTime(2026, 9, 14),
        rangeStart: DateTime(2026, 9, 14),
        rangeEnd: DateTime(2026, 10, 5),
      );

      expect(dates, [
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 5),
      ]);
    });

    test('ogni mese: stesso giorno, e i mesi che non lo hanno lo saltano', () {
      final fifteenth = expandOccurrences(
        parse('FREQ=MONTHLY')!,
        start: DateTime(2026, 9, 15),
        rangeStart: DateTime(2026, 9, 1),
        rangeEnd: DateTime(2026, 11, 30),
      );
      expect(fifteenth, [
        DateTime(2026, 9, 15),
        DateTime(2026, 10, 15),
        DateTime(2026, 11, 15),
      ]);

      // Il 31 esiste a ottobre ma non a novembre: quell'occorrenza si salta,
      // senza "ultimo giorno del mese" implicito e senza crash.
      final thirtyFirst = expandOccurrences(
        parse('FREQ=MONTHLY')!,
        start: DateTime(2026, 10, 31),
        rangeStart: DateTime(2026, 10, 1),
        rangeEnd: DateTime(2026, 12, 31),
      );
      expect(thirtyFirst, [DateTime(2026, 10, 31), DateTime(2026, 12, 31)]);
    });

    test('ogni anno, e il 29 febbraio solo negli anni bisestili', () {
      final yearly = expandOccurrences(
        parse('FREQ=YEARLY')!,
        start: DateTime(2026, 9, 14),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2028, 12, 31),
      );
      expect(yearly, [
        DateTime(2026, 9, 14),
        DateTime(2027, 9, 14),
        DateTime(2028, 9, 14),
      ]);

      final leap = expandOccurrences(
        parse('FREQ=YEARLY')!,
        start: DateTime(2024, 2, 29),
        rangeStart: DateTime(2024, 1, 1),
        rangeEnd: DateTime(2027, 12, 31),
      );
      expect(
          leap,
          [DateTime(2024, 2, 29), DateTime(2028, 2, 29)].where(
            (date) => !date.isAfter(DateTime(2027, 12, 31)),
          ));
    });

    test('until è incluso e chiude la serie', () {
      final dates = expandOccurrences(
        parse('FREQ=DAILY;UNTIL=2026-09-15')!,
        start: DateTime(2026, 9, 13),
        rangeStart: DateTime(2026, 9, 1),
        rangeEnd: DateTime(2026, 9, 30),
      );

      expect(dates.last, DateTime(2026, 9, 15));
      expect(dates, hasLength(3));

      // Una finestra tutta dopo la fine non produce niente: la serie è chiusa.
      expect(
        expandOccurrences(
          parse('FREQ=DAILY;UNTIL=2026-09-15')!,
          start: DateTime(2026, 9, 13),
          rangeStart: DateTime(2026, 10, 1),
          rangeEnd: DateTime(2026, 10, 31),
        ),
        isEmpty,
      );
    });

    test('una finestra di un anno su "ogni giorno" dà 365 date', () {
      final dates = expandOccurrences(
        parse('FREQ=DAILY')!,
        start: DateTime(2026, 1, 1),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 12, 31),
      );

      expect(dates, hasLength(365));
    });
  });

  group('intervallo e conteggio', () {
    test('legge INTERVAL e COUNT e li riscrive', () {
      final rule =
          parse('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO;UNTIL=2026-12-31;COUNT=10');

      expect(rule!.interval, 2);
      expect(rule.count, 10);
      expect(
        rule.toRuleString(),
        'FREQ=WEEKLY;BYDAY=MO;INTERVAL=2;UNTIL=2026-12-31;COUNT=10',
      );
    });

    test('valori invalidi tornano ai default', () {
      expect(parse('FREQ=DAILY;INTERVAL=0')!.interval, 1);
      expect(parse('FREQ=DAILY;INTERVAL=abc')!.interval, 1);
      expect(parse('FREQ=DAILY;COUNT=0')!.count, isNull);
      expect(parse('FREQ=DAILY;COUNT=abc')!.count, isNull);
    });

    test('il default non si serializza', () {
      expect(parse('FREQ=DAILY')!.toRuleString(), 'FREQ=DAILY');
    });

    test('daily ogni 3 giorni resta sulla griglia della prima occorrenza', () {
      // Prima: lun 7 set. La griglia è 7, 10, 13… anche se la finestra parte
      // di giovedì: 9 non esiste come occorrenza.
      final dates = expandOccurrences(
        parse('FREQ=DAILY;INTERVAL=3')!,
        start: DateTime(2026, 9, 7),
        rangeStart: DateTime(2026, 9, 10),
        rangeEnd: DateTime(2026, 9, 25),
      );

      expect(dates, [
        DateTime(2026, 9, 10),
        DateTime(2026, 9, 13),
        DateTime(2026, 9, 16),
        DateTime(2026, 9, 19),
        DateTime(2026, 9, 22),
        DateTime(2026, 9, 25),
      ]);
    });

    test('weekly ogni 2 settimane: solo le settimane della serie', () {
      // Prima: lun 7 set. Le settimane 0 e 2 dalla prima: 7 e 21; il 14 e il 28
      // sono lunedì delle settimane dispari e NON cadono.
      final dates = expandOccurrences(
        parse('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO')!,
        start: DateTime(2026, 9, 7),
        rangeStart: DateTime(2026, 9, 7),
        rangeEnd: DateTime(2026, 10, 4),
      );

      expect(dates, [DateTime(2026, 9, 7), DateTime(2026, 9, 21)]);
    });

    test('monthly ogni 3 mesi: la griglia è ancorata alla prima', () {
      // Prima: gennaio. Griglia gen, apr, lug, ott — febbraio non genera nulla
      // e non sposta la serie su mag.
      final dates = expandOccurrences(
        parse('FREQ=MONTHLY;INTERVAL=3')!,
        start: DateTime(2026, 1, 15),
        rangeStart: DateTime(2026, 2, 1),
        rangeEnd: DateTime(2026, 11, 30),
      );

      expect(dates, [
        DateTime(2026, 4, 15),
        DateTime(2026, 7, 15),
        DateTime(2026, 10, 15),
      ]);
    });

    test('yearly ogni 2 anni resta sugli anni della serie', () {
      final dates = expandOccurrences(
        parse('FREQ=YEARLY;INTERVAL=2')!,
        start: DateTime(2026, 1, 15),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2032, 12, 31),
      );

      expect(dates, [
        DateTime(2026, 1, 15),
        DateTime(2028, 1, 15),
        DateTime(2030, 1, 15),
        DateTime(2032, 1, 15),
      ]);
    });

    test('COUNT conta dalla prima occorrenza, anche fuori finestra', () {
      // Serie: 10, 11, 12. La finestra comincia l'11: le due occorrenze prima
      // (inclusa la 10, nella finestra) e dopo no — restano 11 e 12.
      final dates = expandOccurrences(
        parse('FREQ=DAILY;COUNT=3')!,
        start: DateTime(2026, 9, 10),
        rangeStart: DateTime(2026, 9, 11),
        rangeEnd: DateTime(2026, 9, 30),
      );

      expect(dates, [DateTime(2026, 9, 11), DateTime(2026, 9, 12)]);
    });

    test('COUNT esaurito non genera più nulla', () {
      final dates = expandOccurrences(
        parse('FREQ=DAILY;COUNT=2')!,
        start: DateTime(2026, 9, 10),
        rangeStart: DateTime(2026, 9, 20),
        rangeEnd: DateTime(2026, 9, 30),
      );

      expect(dates, isEmpty);
    });

    test('il mese senza il giorno non consuma COUNT', () {
      // 31 gennaio: febbraio non ha il 31 (l'occorrenza non è mai nata), quindi
      // le tre occorrenze sono gen, mar, mag — non gen, mar, apr.
      final dates = expandOccurrences(
        parse('FREQ=MONTHLY;COUNT=3')!,
        start: DateTime(2026, 1, 31),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 12, 31),
      );

      expect(dates, [
        DateTime(2026, 1, 31),
        DateTime(2026, 3, 31),
        DateTime(2026, 5, 31),
      ]);
    });

    test('etichette con intervallo e conteggio', () {
      final anchor = DateTime(2026, 9, 14); // un lunedì

      expect(
        recurrenceLabel(parse('FREQ=DAILY;INTERVAL=3'), anchor: anchor),
        'ogni 3 giorni',
      );
      expect(
        recurrenceLabel(parse('FREQ=WEEKLY;INTERVAL=2'), anchor: anchor),
        'ogni 2 settimane',
      );
      expect(
        recurrenceLabel(parse('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO'),
            anchor: anchor),
        'ogni 2 settimane il lunedì',
      );
      expect(
        recurrenceLabel(
          parse('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TU,WE,TH,FR'),
          anchor: anchor,
        ),
        'ogni 2 settimane il lun-ven',
      );
      expect(
        recurrenceLabel(parse('FREQ=MONTHLY;INTERVAL=6'), anchor: anchor),
        'ogni 6 mesi il 14',
      );
      expect(
        recurrenceLabel(parse('FREQ=YEARLY;INTERVAL=2'), anchor: anchor),
        'ogni 2 anni',
      );
      expect(
        recurrenceLabel(parse('FREQ=DAILY;COUNT=5'), anchor: anchor),
        'ogni giorno, 5 volte',
      );
      expect(
        recurrenceLabel(parse('FREQ=DAILY;UNTIL=2026-12-31;COUNT=5'),
            anchor: anchor),
        'ogni giorno, 5 volte fino al 31/12/2026',
      );
    });
  });
}
