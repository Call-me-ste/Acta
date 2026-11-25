import 'package:flutter/material.dart';

/// La griglia delle 24 ore: **un disegno solo**, non 24 righe di widget.
///
/// Perché: la vista Giorno è quella che il fotogramma del cambio vista paga di
/// più. Le 24 righe erano 24 `Row` da cinque widget l'una (~120 widget disegnati
/// a ogni ingresso in scena: la suite dei cambi vista la indica come la cara —
/// settimana→giorno 12,8 ms, giorno→mese 13,4, mentre mese→settimana sta a 8,7).
/// Qui sono un `CustomPaint`: una linea per ora, e le etichette misurate **una
/// volta per stile** come i nomi dei giorni nel mese.
///
/// La forma non cambia: l'etichetta a sinistra, e la linea sottile da lì al bordo
/// destro, **centrate nella fascia della loro ora** (è dove le metteva il `Row`
/// di prima).
class DayHourGrid extends StatefulWidget {
  const DayHourGrid({
    super.key,
    required this.hourHeight,
    required this.gutter,
  });

  final double hourHeight;

  /// Quanto spazio prende la colonna delle ore a sinistra.
  final double gutter;

  @override
  State<DayHourGrid> createState() => _DayHourGridState();
}

class _DayHourGridState extends State<DayHourGrid> {
  /// Le 24 etichette misurate, tenute finché lo stile non cambia: misurarle a ogni
  /// disegno sarebbe il lavoro che questa griglia esiste per togliere.
  List<TextPainter>? _ore;
  TextStyle? _stile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stile = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (_ore == null || _stile != stile) {
      _stile = stile;
      _ore = [
        for (var ora = 0; ora < 24; ora++)
          TextPainter(
            text: TextSpan(
              text: '${ora.toString().padLeft(2, '0')}:00',
              style: stile,
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
      ];
    }

    return CustomPaint(
      size: Size.infinite,
      painter: GrigliaDelleOre(
        ore: _ore!,
        hourHeight: widget.hourHeight,
        gutter: widget.gutter,
        coloreLinea: theme.colorScheme.outlineVariant,
        // Sottile come il `Divider(height: 1)` che c'era prima: un pixel
        // **fisico**, non uno logico (su questo schermo un terzo).
        spessoreLinea: 1 / MediaQuery.devicePixelRatioOf(context),
      ),
    );
  }
}

/// Disegna le 24 fasce: l'etichetta e la riga, allineate al centro della fascia.
class GrigliaDelleOre extends CustomPainter {
  const GrigliaDelleOre({
    required this.ore,
    required this.hourHeight,
    required this.gutter,
    required this.coloreLinea,
    required this.spessoreLinea,
  });

  final List<TextPainter> ore;
  final double hourHeight;
  final double gutter;
  final Color coloreLinea;
  final double spessoreLinea;

  @override
  void paint(Canvas canvas, Size size) {
    final pennello = Paint()
      ..color = coloreLinea
      ..strokeWidth = spessoreLinea;

    for (var ora = 0; ora < ore.length; ora++) {
      final centro = ora * hourHeight + hourHeight / 2;
      canvas.drawLine(
          Offset(gutter, centro), Offset(size.width, centro), pennello);

      final etichetta = ore[ora];
      etichetta.paint(
        canvas,
        Offset(0, centro - etichetta.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(GrigliaDelleOre vecchio) =>
      vecchio.ore != ore ||
      vecchio.hourHeight != hourHeight ||
      vecchio.gutter != gutter ||
      vecchio.coloreLinea != coloreLinea ||
      vecchio.spessoreLinea != spessoreLinea;
}
