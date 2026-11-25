import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/settings/priority_colors.dart';
import 'package:planner/ui/shared/color_name.dart';

/// Il nome di un colore: quello che si legge al posto del codice esadecimale.
///
/// Si calcola dal colore, quindi vale per qualunque tinta — compresa quella
/// scelta a mano — e non c'e' un elenco da tenere aggiornato.
void main() {
  test('i quattro colori di base si chiamano come si dice', () {
    expect(colorNameOfHex(defaultPriorityColors[0]), 'Verde');
    expect(colorNameOfHex(defaultPriorityColors[1]), 'Giallo');
    expect(colorNameOfHex(defaultPriorityColors[2]), 'Arancione');
    expect(colorNameOfHex(defaultPriorityColors[3]), 'Rosso');
  });

  test('i grigi non sono tinte sbiadite', () {
    expect(colorNameFor(Colors.white), 'Bianco');
    expect(colorNameFor(Colors.black), 'Nero');
    expect(colorNameFor(const Color(0xFF808080)), 'Grigio');
    expect(colorNameFor(const Color(0xFFDDDDDD)), 'Grigio chiaro');
    expect(colorNameFor(const Color(0xFF333333)), 'Grigio scuro');
  });

  test('chiaro e scuro si dicono quando servono a distinguere', () {
    expect(colorNameFor(const Color(0xFFE1F5FE)), 'Azzurro chiaro');
    expect(colorNameFor(const Color(0xFF0A0A2A)), 'Blu scuro');
    // Un azzurro pieno non ha bisogno di altre parole.
    expect(colorNameFor(const Color(0xFF2196F3)), 'Azzurro');
  });

  test('le famiglie principali hanno il loro nome', () {
    expect(colorNameFor(const Color(0xFF4CAF50)), 'Verde');
    expect(colorNameFor(const Color(0xFF9C27B0)), 'Viola');
    expect(colorNameFor(const Color(0xFFE91E63)), 'Rosa');
    expect(colorNameFor(const Color(0xFF795548)), 'Marrone');
    // Un arancione pieno resta arancione: il marrone e' scuro e poco acceso.
    expect(colorNameFor(const Color(0xFFFF9800)), 'Arancione');
  });

  test('un codice illeggibile non lascia la riga vuota', () {
    expect(colorNameOfHex('ciao'), 'Colore');
    expect(colorNameOfHex(null), 'Colore');
    expect(colorNameOfHex('#12345'), 'Colore');
    // Il cancelletto non serve: il codice si legge lo stesso.
    expect(colorNameOfHex('f44336'), 'Rosso');
  });
}
