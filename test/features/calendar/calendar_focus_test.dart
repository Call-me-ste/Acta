import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/calendar/calendar_focus.dart';
import 'package:planner/features/settings/app_settings_controller.dart';

/// Quando serve il comando «Torna a oggi»: una domanda con una risposta esatta,
/// quindi si prova con le date invece che a occhio sullo schermo.
void main() {
  // Riferimento: giovedi' 17 settembre 2026.
  final oggi = DateTime(2026, 9, 17, 12);

  bool serve({
    CalendarView vista = CalendarView.mese,
    DateTime? scelto,
    DateTime? guardato,
  }) {
    return shouldOfferToday(
      view: vista,
      selectedDay: scelto ?? oggi,
      focusedDay: guardato ?? oggi,
      today: oggi,
    );
  }

  test('guardando oggi, mese, settimana e giorno non serve', () {
    expect(serve(), isFalse);
    expect(serve(vista: CalendarView.settimana), isFalse);
    expect(serve(vista: CalendarView.giorno), isFalse);
  });

  test('un altro giorno scelto: serve in tutte le viste', () {
    final altro = DateTime(2026, 9, 15);
    expect(serve(scelto: altro), isTrue);
    expect(serve(vista: CalendarView.settimana, scelto: altro), isTrue);
    expect(serve(vista: CalendarView.giorno, scelto: altro), isTrue);
  });

  test('altro mese guardato, oggi scelto: serve solo nel mese', () {
    expect(serve(guardato: DateTime(2026, 10, 1)), isTrue);
    // In settimana e giorno la griglia non "guarda un mese": non serve.
    expect(
      serve(vista: CalendarView.settimana, guardato: DateTime(2026, 10, 1)),
      isFalse,
    );
    expect(
      serve(vista: CalendarView.giorno, guardato: DateTime(2026, 10, 1)),
      isFalse,
    );
  });

  test('stesso mese ma altra settimana: il mese non se ne accorge', () {
    // Il 3 settembre e' nella settimana del 31 agosto: oggi scelto, ma la
    // selezione e' un altro giorno, quindi serve comunque.
    expect(serve(scelto: DateTime(2026, 9, 3)), isTrue);
  });

  test('la settimana si conta dal lunedi\': domenica e lunedi\' sono diverse', () {
    // Domenica 20 settembre e' nella settimana del 14; lunedi' 21 in quella dopo.
    expect(stessaSettimana(DateTime(2026, 9, 20), oggi), isTrue);
    expect(stessaSettimana(DateTime(2026, 9, 21), oggi), isFalse);
    expect(serve(vista: CalendarView.settimana, scelto: DateTime(2026, 9, 21)),
        isTrue);
  });
}
