import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/palette/domain/armonia.dart';

/// La matematica delle tinte: conversioni e distanze.
///
/// Si prova con i **numeri** e non a occhio: sono questi valori che decidono se
/// due colori si distinguono e se una famiglia e' coerente, quindi devono
/// restare esatti anche quando intorno cambia tutto.
void main() {
  group('hsl', () {
    test('i primari stanno dove dice la ruota', () {
      expect(Armonia.hsl('#ff0000'), [0.0, 1.0, 0.5]);
      expect(Armonia.hsl('#00ff00'), [120.0, 1.0, 0.5]);
      expect(Armonia.hsl('#0000ff'), [240.0, 1.0, 0.5]);
    });

    test('un grigio ha saturazione zero', () {
      final hsl = Armonia.hsl('#808080')!;
      expect(hsl[1], 0.0);
      expect(hsl[2], closeTo(0.5, 0.01));
    });

    test('accetta le forme corte, con o senza cancelletto', () {
      expect(Armonia.hsl('#f0a'), Armonia.hsl('#ff00aa'));
      expect(Armonia.hsl('ff69b4'), Armonia.hsl('#FF69B4'));
    });

    test('un colore illeggibile non inventa niente', () {
      for (final rotto in ['', '#', 'rosso', '#12345', '#gggggg', '#1234567']) {
        expect(Armonia.hsl(rotto), isNull, reason: '«$rotto»');
        expect(Armonia.tinta(rotto), isNull, reason: '«$rotto»');
        expect(Armonia.luminosita(rotto), isNull, reason: '«$rotto»');
      }
    });
  });

  group('distanzaTinta', () {
    test('sul giro corto: 348° e 12° distano 24', () {
      // Due tinte a 12° dal rosso nei due versi: la distanza vera e' 24,
      // non 336. Gli hex sono scelti cosi' che la tinta sia esatta (51/255*60).
      expect(
        Armonia.distanzaTinta('#ff3300', '#ff0033'),
        closeTo(24, 0.01),
      );
    });

    test('stesso colore: zero, opposti: 180', () {
      expect(Armonia.distanzaTinta('#1976d2', '#1976d2'), 0);
      expect(
        Armonia.distanzaTinta('#ff0000', '#00ffff'),
        closeTo(180, 0.01),
        reason: 'esattamente dall\'altra parte della ruota',
      );
    });

    test('un colore rotto non e\' mai vicino', () {
      expect(Armonia.distanzaTinta('rosso', '#1976d2'), 360);
    });
  });
}
