import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/ui/shared/color_wheel_geometry.dart';

/// La geometria della ruota: **punto ↔ tinta e saturazione**. È aritmetica pura,
/// quindi si prova senza schermo — ed è la stessa che usano disegno e gesto, quindi
/// se sbaglia qui sbaglia anche quello che si vede.
void main() {
  // Ruota centrata in (100, 100), raggio 100: l'anello va da 55 a 100.
  const ruota = ColorWheelGeometry(
    center: Offset(100, 100),
    radius: 100,
  );

  test('l\'angolo è la tinta, in senso orario dall\'asse x', () {
    // A destra: tinta 0 (rosso).
    expect(ruota.daPunto(const Offset(150, 100)).hue, closeTo(0, 0.01));
    // In basso: 90° (giallo-verde nel giro di `SweepGradient`).
    expect(ruota.daPunto(const Offset(100, 150)).hue, closeTo(90, 0.01));
    // A sinistra: 180°.
    expect(ruota.daPunto(const Offset(50, 100)).hue, closeTo(180, 0.01));
    // In alto: 270°.
    expect(ruota.daPunto(const Offset(100, 50)).hue, closeTo(270, 0.01));
  });

  test('la distanza dal centro è la saturazione, e si ferma agli estremi', () {
    // Sull'anello esterno: saturazione piena.
    expect(ruota.daPunto(const Offset(200, 100)).saturation, closeTo(1, 0.01));
    // A metà anello: circa metà saturazione.
    final mezzo = ruota.inner + ruota.larghezzaAnello / 2;
    expect(
      ruota.daPunto(Offset(100 + mezzo, 100)).saturation,
      closeTo(0.5, 0.01),
    );
    // Dentro il buco e fuori dal bordo: si limita, non sfora.
    expect(ruota.daPunto(const Offset(100, 100)).saturation, 0);
    expect(ruota.daPunto(const Offset(400, 100)).saturation, 1);
  });

  test('tinta e saturazione tornano al punto da cui vengono (dentro l\'anello)',
      () {
    // Solo i punti **dentro l'anello**: nel buco la saturazione è zero per
    // definizione, quindi tornare allo stesso punto è impossibile (e non serve).
    for (final punto in const [
      Offset(190, 100),
      Offset(100, 30),
      Offset(60, 60),
      Offset(140, 160),
      Offset(30, 140),
    ]) {
      final letto = ruota.daPunto(punto);
      final tornato = ruota.puntoDi(
        hue: letto.hue,
        saturation: letto.saturation,
      );
      expect(tornato.dx, closeTo(punto.dx, 0.01));
      expect(tornato.dy, closeTo(punto.dy, 0.01));
    }
  });

  test('dentro il buco il cursore va sull\'anello, non al centro', () {
    // Toccando il centro la saturazione è zero: il cursore si mette sul bordo
    // interno dell'anello, dove la ruota comincia. Al centro non ci sarebbe
    // nessun colore da mostrare.
    final letto = ruota.daPunto(const Offset(100, 90));
    expect(letto.saturation, 0);
    expect(letto.hue, closeTo(270, 0.01));

    final tornato = ruota.puntoDi(hue: letto.hue, saturation: 0);
    expect(tornato.dy, closeTo(45, 0.01), reason: 'sul bordo interno');
  });

  test('il raggio tiene conto della frazione interna', () {
    final dentro = ruota.puntoDi(hue: 0, saturation: 0);
    final fuori = ruota.puntoDi(hue: 0, saturation: 1);

    expect(dentro.dx, closeTo(100 + ruota.inner, 0.01));
    expect(fuori.dx, closeTo(200, 0.01));
    // Una saturazione fuori scala non manda il cursore a spasso.
    expect(ruota.puntoDi(hue: 0, saturation: 3).dx, closeTo(200, 0.01));
    expect(ruota.puntoDi(hue: 0, saturation: -2).dx, closeTo(155, 0.01));
  });

  test('la ruota sta dentro il riquadro, anche se non è quadrato', () {
    final geometria = ColorWheelGeometry.nelRiquadro(const Size(200, 120));

    expect(geometria.radius, 60, reason: 'il lato minore');
    expect(geometria.center, const Offset(100, 60));
  });

  test('l\'angolo di un punto è quello che si aspetta', () {
    // Controllo incrociato con `atan2`: la formula della ruota non deve avere una
    // convenzione sua.
    const punto = Offset(140, 160);
    final atteso =
        (math.atan2(punto.dy - 100, punto.dx - 100) * 180 / math.pi + 360) %
            360;
    expect(ruota.daPunto(punto).hue, closeTo(atteso, 0.01));
  });
}
