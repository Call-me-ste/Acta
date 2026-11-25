import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/events/domain/day_layout.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/domain/event_occurrence.dart';

EventOccurrence _occ(DateTime start, DateTime end) => EventOccurrence(
      event: Event(id: 'e', title: 'e', start: start, end: end),
      date: DateTime(start.year, start.month, start.day),
      start: start,
      end: end,
    );

/// La geometria della vista giorno si verifica qui, senza widget: è logica
/// pura, e un numero sbagliato qui diventa un evento disegnato nel posto
/// sbagliato.
void main() {
  group('DayLayout.place', () {
    test('un evento di 15 minuti cade nel suo minuto', () {
      final placed = DayLayout.place([
        _occ(DateTime(2026, 9, 14, 9, 15), DateTime(2026, 9, 14, 9, 30)),
      ], day: DateTime(2026, 9, 14));

      expect(placed, hasLength(1));
      expect(placed.single.offsetMinutes, 9 * 60 + 15);
      expect(placed.single.durationMinutes, 15);
      expect(placed.single.lane, 0);
    });

    test('due eventi sovrapposti vanno in corsie diverse', () {
      final placed = DayLayout.place([
        _occ(DateTime(2026, 9, 14, 9), DateTime(2026, 9, 14, 10)),
        _occ(DateTime(2026, 9, 14, 9, 30), DateTime(2026, 9, 14, 10, 30)),
      ], day: DateTime(2026, 9, 14));

      expect(placed[0].lane, isNot(placed[1].lane));
      expect(DayLayout.columnsFor(placed), 2);
    });

    test('due eventi in sequenza condividono la corsia', () {
      final placed = DayLayout.place([
        _occ(DateTime(2026, 9, 14, 9), DateTime(2026, 9, 14, 10)),
        _occ(DateTime(2026, 9, 14, 10), DateTime(2026, 9, 14, 11)),
      ], day: DateTime(2026, 9, 14));

      expect(placed[0].lane, 0);
      expect(placed[1].lane, 0);
      expect(DayLayout.columnsFor(placed), 1);
    });

    test('un evento a cavallo di mezzanotte viene limitato al giorno', () {
      final placed = DayLayout.place([
        _occ(DateTime(2026, 9, 13, 23, 30), DateTime(2026, 9, 14, 0, 30)),
      ], day: DateTime(2026, 9, 13));

      expect(placed.single.offsetMinutes, 23 * 60 + 30);
      expect(placed.single.durationMinutes, 30);
    });

    test('un evento iniziato ieri comincia a mezzanotte', () {
      final placed = DayLayout.place([
        _occ(DateTime(2026, 9, 12, 22), DateTime(2026, 9, 13, 9)),
      ], day: DateTime(2026, 9, 13));

      expect(placed.single.offsetMinutes, 0);
      expect(placed.single.durationMinutes, 9 * 60);
    });

    test('un evento di un altro giorno non appare', () {
      final placed = DayLayout.place([
        _occ(DateTime(2026, 9, 14, 9), DateTime(2026, 9, 14, 10)),
      ], day: DateTime(2026, 9, 13));

      expect(placed, isEmpty);
    });
  });

  group('DayLayout.corsie — i blocchi generici (eventi e todo misti)', () {
    test('due blocchi sovrapposti stanno in corsie diverse', () {
      final corsie = DayLayout.corsie(const [(540, 600), (570, 660)]);

      expect(corsie, [0, 1]);
      expect(DayLayout.quante(corsie), 2);
    });

    test('in sequenza condividono la corsia, e l\'ordine dato torna', () {
      // Il primo elenco finisce **dentro** il secondo (570 sta nei 540-600): va
      // in corsia 1, ma il risultato resta nell'ordine di chi ha chiamato.
      final fuoriOrdine = DayLayout.corsie(const [(570, 660), (540, 600)]);
      expect(fuoriOrdine, [1, 0]);
      expect(DayLayout.quante(fuoriOrdine), 2);

      // Che si tocchino basta a condividere: la fine di uno è l'inizio
      // dell'altro — la stessa regola di sempre (`!isAfter`).
      final inSequenza = DayLayout.corsie(const [(540, 600), (600, 660)]);
      expect(inSequenza, [0, 0]);
      expect(DayLayout.quante(inSequenza), 1);
    });

    test('tre contemporanei: tre corsie, e il quarto riusa la prima', () {
      final corsie = DayLayout.corsie(const [
        (540, 780),
        (545, 600),
        (550, 630),
        (780, 840),
      ]);

      expect(corsie, [0, 1, 2, 0]);
      expect(DayLayout.quante(corsie), 3);
    });

    test('nessun blocco: una corsia sola, non zero', () {
      expect(DayLayout.quante(DayLayout.corsie(const [])), 1);
    });
  });
}
