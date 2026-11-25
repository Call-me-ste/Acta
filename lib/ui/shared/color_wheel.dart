import 'package:flutter/material.dart';

import 'color_wheel_geometry.dart';

/// La ruota dei colori: la **tinta** gira intorno, la **saturazione** va dal centro
/// al bordo. Si trascina, e il colore cambia mentre il dito si muove.
///
/// Sostituisce i tre slider (Tinta, Saturazione, Luminosità) del selettore: due
/// delle tre cose si scelgono in un gesto solo, e la ruota è il modo in cui tutti
/// si aspettano di scegliere un colore. La luminosità resta una barra a parte
/// (`BarraLuminosita`), perché in una ruota a due dimensioni non ci sta.
///
/// Il disegno è **un `CustomPainter`**: la ruota è una ventina di anelli con un
/// gradiente di tinta ciascuno, non centinaia di widget. Il cursore invece è un
/// widget posizionato, così spostarlo non ridipinge la ruota: il pennello si
/// ridisegna solo quando cambia la luminosità (o la misura), non a ogni tinta.
class ColorWheel extends StatelessWidget {
  const ColorWheel({
    super.key,
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.onChanged,
    this.side = 168,
  });

  /// Tinta in gradi (0-360), saturazione (0-1) e luminosità (0-1): sono lo
  /// stato di chi ci mette la ruota, non di chi la disegna. La ruota usa **la
  /// luminosità scelta**, così il colore che si vede è quello che verrà salvato.
  final double hue;
  final double saturation;
  final double lightness;

  final void Function(double hue, double saturation) onChanged;

  /// Il lato della ruota. 168 sta comodo in un dialogo su un telefono, con la
  /// barra della luminosità sotto.
  final double side;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SizedBox(
        width: side,
        height: side,
        child: Semantics(
          label: 'Ruota dei colori',
          value: 'tinta ${hue.round()}, saturazione '
              '${(saturation * 100).round()} per cento',
          child: LayoutBuilder(
            builder: (context, vincoli) {
              final misura = Size(vincoli.maxWidth, vincoli.maxHeight);
              final geometria = ColorWheelGeometry.nelRiquadro(misura);
              final cursore = geometria.puntoDi(
                hue: hue,
                saturation: saturation,
              );

              void scegli(Offset punto) {
                final scelto = geometria.daPunto(punto);
                onChanged(scelto.hue, scelto.saturation);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (dettagli) => scegli(dettagli.localPosition),
                onPanStart: (dettagli) => scegli(dettagli.localPosition),
                onPanUpdate: (dettagli) => scegli(dettagli.localPosition),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RuotaDeiColori(
                          geometria: geometria,
                          lightness: lightness,
                        ),
                      ),
                    ),
                    Positioned(
                      left: cursore.dx - 12,
                      top: cursore.dy - 12,
                      child: _Cursore(
                        colore: HSLColor.fromAHSL(
                          1,
                          hue,
                          saturation,
                          lightness,
                        ).toColor(),
                        bordo: scheme.surface,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Il pennello della ruota: una ventina di anelli, ognuno col suo giro di tinte.
///
/// Perché anelli e non un `SweepGradient` con una tinta sbiadita sopra: mescolare
/// col bianco verso il centro **schiarisce** il colore invece di desaturarlo, e la
/// ruota non direbbe la verità su quello che si sta scegliendo. Venti anelli sono
/// venti disegni, fatti **una volta** (il pennello non si ridipinge mentre si
/// trascina: cambia solo il cursore).
class _RuotaDeiColori extends CustomPainter {
  const _RuotaDeiColori({
    required this.geometria,
    required this.lightness,
  });

  final ColorWheelGeometry geometria;

  /// La luminosità scelta: la ruota la usa **per intero**, così l'anello che si
  /// tocca è già il colore che verrà salvato. Prima gli anelli erano fissi a 0,5
  /// e l'anteprima sembrava un altro colore.
  final double lightness;

  /// Quanti anelli: sotto una ventina si vedono le scalettature, sopra è lavoro
  /// sprecato (l'occhio non distingue più).
  static const int anelli = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final passo = geometria.larghezzaAnello / anelli;

    for (var indice = 0; indice < anelli; indice++) {
      // Saturazione a metà dell'anello: è il colore che quel pixel rappresenta.
      final saturazione = (indice + 0.5) / anelli;
      final raggio = geometria.inner + passo * (indice + 0.5);

      canvas.drawCircle(
        geometria.center,
        raggio,
        Paint()
          ..style = PaintingStyle.stroke
          // mezzo pixel di sovrapposizione: senza, fra un anello e l'altro resta
          // una riga chiara
          ..strokeWidth = passo + 0.5
          ..shader = SweepGradient(
            colors: _tinte(saturazione, lightness),
          ).createShader(
            Rect.fromCircle(
              center: geometria.center,
              radius: geometria.radius,
            ),
          ),
      );
    }
  }

  /// Le sette tinte del giro, alla saturazione data: rosso, giallo, verde, ciano,
  /// blu, magenta e di nuovo rosso (le posizioni le mette `SweepGradient`).
  static List<Color> _tinte(double saturazione, double luminosita) => [
        for (final tinta in const [0, 60, 120, 180, 240, 300, 360])
          HSLColor.fromAHSL(
            1,
            tinta.toDouble(),
            saturazione,
            luminosita,
          ).toColor(),
      ];

  @override
  bool shouldRepaint(_RuotaDeiColori vecchio) =>
      vecchio.geometria.center != geometria.center ||
      vecchio.geometria.radius != geometria.radius ||
      vecchio.lightness != lightness;
}

/// Il pallino che dice dove sei sulla ruota: il colore scelto dentro, un bordo del
/// colore del foglio intorno (così si vede anche sui colori chiari).
class _Cursore extends StatelessWidget {
  const _Cursore({required this.colore, required this.bordo});

  final Color colore;
  final Color bordo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: colore,
        shape: BoxShape.circle,
        border: Border.all(color: bordo, width: 3),
      ),
    );
  }
}
