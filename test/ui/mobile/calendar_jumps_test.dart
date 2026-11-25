import 'package:flutter_test/flutter_test.dart';

import 'package:planner/ui/mobile/calendar_jumps.dart';

/// I salti di giorno sbagliano facilmente sugli estremi: il 31 in un mese da 30
/// giorni, il 29 febbraio, il capodanno. Qui si provano **da soli**, senza
/// alzare una schermata.
void main() {
  group('piuGiorni', () {
    test('avanti e indietro a cavallo del mese e dell\'anno', () {
      expect(
        CalendarJumps.piuGiorni(DateTime(2026, 9, 30), 1),
        DateTime(2026, 10, 1),
      );
      expect(
        CalendarJumps.piuGiorni(DateTime(2026, 12, 31), 1),
        DateTime(2027, 1, 1),
      );
      expect(
        CalendarJumps.piuGiorni(DateTime(2027, 1, 1), -1),
        DateTime(2026, 12, 31),
      );
      expect(
        CalendarJumps.piuGiorni(DateTime(2026, 3, 1), -1),
        DateTime(2026, 2, 28),
      );
    });

    test('la settimana sono sette giorni, anche con l\'ora legale di mezzo',
        () {
      // In Italia l'ora legale finisce l'ultima domenica di ottobre: in quei
      // giorni una giornata dura 25 ore, e con una Duration il conto salterebbe.
      expect(
        CalendarJumps.piuGiorni(DateTime(2026, 10, 24), 7),
        DateTime(2026, 10, 31),
      );
      expect(
        CalendarJumps.distanzaInGiorni(
          DateTime(2026, 10, 24),
          DateTime(2026, 10, 31),
        ),
        7,
      );
    });
  });
}
