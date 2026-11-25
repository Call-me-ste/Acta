import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/events/domain/time_rules.dart';

/// Le regole dei campi orari incompleti. Numeri, non quadrante: cambiare l'ora
/// di inizio a 21:00 significa «dalle 21 all'una»? No: significa un'ora.
void main() {
  group('cambiare l\'inizio', () {
    test('sposta la fine di un\'ora quando la fine non ci sta più dietro', () {
      // Inizio portato alle 21:00, la fine era le 10:00.
      expect(
        EventTimeRules.endFor(
          startMinutes: 21 * 60,
          currentEndMinutes: 10 * 60,
        ),
        22 * 60,
      );
    });

    test('lascia la fine scelta se è ancora dopo l\'inizio', () {
      expect(
        EventTimeRules.endFor(startMinutes: 9 * 60, currentEndMinutes: 11 * 60),
        11 * 60,
      );
    });

    test('a fine giornata non scavalca la mezzanotte', () {
      expect(
        EventTimeRules.endFor(
          startMinutes: 23 * 60 + 30,
          currentEndMinutes: 10 * 60,
        ),
        EventTimeRules.lastMinuteOfDay,
      );
    });
  });

  group('cambiare la fine', () {
    test('sposta l\'inizio di un\'ora indietro quando serve', () {
      // Fine portata alle 08:00, l'inizio era alle 09:00.
      expect(
        EventTimeRules.startFor(
          endMinutes: 8 * 60,
          currentStartMinutes: 9 * 60,
        ),
        7 * 60,
      );
    });

    test('lascia l\'inizio scelto se è ancora prima della fine', () {
      expect(
        EventTimeRules.startFor(
            endMinutes: 11 * 60, currentStartMinutes: 9 * 60),
        9 * 60,
      );
    });

    test('a inizio giornata non va sotto mezzanotte', () {
      expect(
        EventTimeRules.startFor(endMinutes: 20, currentStartMinutes: 9 * 60),
        0,
      );
    });
  });

  group('etichetta della durata', () {
    test('parla come una persona', () {
      expect(EventTimeRules.durationLabel(45), '45 min');
      expect(EventTimeRules.durationLabel(60), '1 h');
      expect(EventTimeRules.durationLabel(90), '1 h 30 min');
      expect(EventTimeRules.durationLabel(0), '0 min');
      expect(
        EventTimeRules.durationMinutes(
          startMinutes: 9 * 60,
          endMinutes: 10 * 60,
        ),
        60,
      );
    });
  });
}
