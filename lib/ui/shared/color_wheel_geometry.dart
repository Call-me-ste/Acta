import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// La geometria della ruota dei colori: **punto ↔ tinta e saturazione**.
///
/// Sta fuori dal widget per lo stesso motivo della geometria del mese: è
/// aritmetica, e la usano il disegno, il gesto e i test. Una regola sola non può
/// divergere da sé stessa, e si prova senza schermo.
///
/// Come si legge la ruota: **l'angolo è la tinta** (0 rosso sull'asse x, in senso
/// orario — è il verso in cui `SweepGradient` disegna) e **la distanza dal centro è
/// la saturazione** (0 al centro, 1 sul bordo). La luminosità non sta qui: è la
/// barra sotto, perché in una ruota bidimensionale non ci sta.
class ColorWheelGeometry {
  const ColorWheelGeometry({
    required this.center,
    required this.radius,
    this.innerRatio = 0.55,
  });

  final Offset center;
  final double radius;

  /// Dove comincia l'anello. Al centro la tinta non esiste (saturazione zero) e
  /// un cursore lì sarebbe ambiguo: la ruota comincia a [innerRatio] del raggio.
  final double innerRatio;

  double get inner => radius * innerRatio;

  double get larghezzaAnello => radius - inner;

  /// Il punto sotto il dito → tinta (0-360) e saturazione (0-1).
  ({double hue, double saturation}) daPunto(Offset punto) {
    final dx = punto.dx - center.dx;
    final dy = punto.dy - center.dy;
    final hue = (math.atan2(dy, dx) * 180 / math.pi + 360) % 360;
    final distanza = math.sqrt(dx * dx + dy * dy);
    final saturazione = larghezzaAnello <= 0
        ? 0.0
        : ((distanza - inner) / larghezzaAnello).clamp(0.0, 1.0);
    return (hue: hue, saturation: saturazione);
  }

  /// Tinta e saturazione → il punto, per disegnare il cursore.
  Offset puntoDi({required double hue, required double saturation}) {
    final raggio = inner + larghezzaAnello * saturation.clamp(0.0, 1.0);
    final radianti = hue * math.pi / 180;
    return center + Offset(math.cos(radianti), math.sin(radianti)) * raggio;
  }

  /// La ruota dentro un riquadro **quadrato** di lato minore.
  static ColorWheelGeometry nelRiquadro(
    Size misura, {
    double innerRatio = 0.55,
  }) {
    final lato = math.min(misura.width, misura.height);
    return ColorWheelGeometry(
      center: Offset(misura.width / 2, misura.height / 2),
      radius: lato / 2,
      innerRatio: innerRatio,
    );
  }
}
