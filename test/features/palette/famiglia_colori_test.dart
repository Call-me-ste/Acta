import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/palette/domain/armonia.dart';
import 'package:planner/features/palette/domain/presets.dart';
import 'package:planner/theme/color_resolver.dart';

/// Le famiglie di colori: **distinzione** e **contrasto**, coi numeri.
///
/// Questo test è anche la **guardia anti-generatore**: le tabelle qui sotto
/// sono copiate a mano da quelle vere e vengono confrontate valore per valore.
/// Se qualcuno reintroduce un generatore, i colori calcolati non coincidono con
/// queste costanti e il test va rosso — com'è giusto che sia: i colori in
/// schermata vengono dalle tabelle o non esistono.
void main() {
  const tabelle = <String, List<String>>{
    'neutro': [
      '#372C25',
      '#816756',
      '#B8A599',
      '#E5DFDC',
      '#2C333A',
      '#637483',
      '#A9B3BC',
      '#E3E6E8',
    ],
    'colore-rosso': [
      '#7E1B1B',
      '#D43535',
      '#E89292',
      '#A51D5C',
      '#E25A9A',
      '#F1D0DF',
      '#A55C1D',
      '#E29A5A',
    ],
    'colore-arancione': [
      '#7E4D1B',
      '#D48635',
      '#E8BD92',
      '#A5221D',
      '#E2605A',
      '#F1D1D0',
      '#A5A11D',
      '#E2DE5A',
    ],
    'colore-giallo': [
      '#7E791B',
      '#D4CC35',
      '#E8E392',
      '#A55E1D',
      '#E29C5A',
      '#F1E0D0',
      '#6CA51D',
      '#AAE25A',
    ],
    'colore-verde': [
      '#1B7E1F',
      '#35D43C',
      '#92E895',
      '#57A51D',
      '#94E25A',
      '#DEF1D0',
      '#1DA562',
      '#5AE29F',
    ],
    'colore-turchese': [
      '#1B737E',
      '#35C3D4',
      '#92DEE8',
      '#1DA574',
      '#5AE2B1',
      '#D0F1E5',
      '#1D57A5',
      '#5A94E2',
    ],
    'colore-blu': [
      '#1B437E',
      '#3575D4',
      '#92B4E8',
      '#1D93A5',
      '#5AD0E2',
      '#D0EDF1',
      '#261DA5',
      '#635AE2',
    ],
    'colore-viola': [
      '#611B7E',
      '#A535D4',
      '#CE92E8',
      '#3D1DA5',
      '#7A5AE2',
      '#D8D0F1',
      '#A51D8E',
      '#E25ACB',
    ],
    'colore-rosa': [
      '#7E1B4D',
      '#D43585',
      '#E892BD',
      '#A51DA0',
      '#E25ADD',
      '#F1D0F0',
      '#A51D22',
      '#E25A5F',
    ],
  };

  /// `true` se i due colori si **distinguono**: almeno 25° di tinta oppure
  /// almeno 0.18 di luminosità. Due grigi puri non hanno tinta: si guardano
  /// solo in luminosità.
  bool siDistinguono(String a, String b) {
    final ha = Armonia.hsl(a)!;
    final hb = Armonia.hsl(b)!;
    final tinta =
        ha[1] < 0.02 && hb[1] < 0.02 ? 0.0 : Armonia.distanzaTinta(a, b);
    return tinta >= 25 || (ha[2] - hb[2]).abs() >= 0.18;
  }

  test('in produzione ci sono solo le tabelle, valore per valore', () {
    expect(famigliaNeutro, tabelle['neutro']);
    for (final palette in presetColori) {
      expect(palette.colors, tabelle[palette.id],
          reason: '${palette.id}: nessun colore calcolato, solo tabelle');
    }
  });

  test('ogni coppia di una famiglia si distingue', () {
    for (final entry in tabelle.entries) {
      final colors = entry.value;
      expect(colors, hasLength(8), reason: entry.key);
      expect(colors.toSet(), hasLength(8), reason: entry.key);
      for (var i = 0; i < colors.length; i++) {
        for (var j = i + 1; j < colors.length; j++) {
          expect(
            siDistinguono(colors[i], colors[j]),
            isTrue,
            reason: '${entry.key}: ${colors[i]} e ${colors[j]} non si '
                'distinguono (tinta ${Armonia.distanzaTinta(colors[i], colors[j]).toStringAsFixed(1)}°, '
                'luce ${(Armonia.luminosita(colors[i])! - Armonia.luminosita(colors[j])!).abs().toStringAsFixed(2)})',
          );
        }
      }
    }
  });

  test('gli otto temi si distinguono fra loro', () {
    final semi = [for (final palette in presetColori) palette.seedHex];
    expect(semi, hasLength(8));
    for (var i = 0; i < semi.length; i++) {
      for (var j = i + 1; j < semi.length; j++) {
        expect(
          siDistinguono(semi[i], semi[j]),
          isTrue,
          reason: '${presetColori[i].name} e ${presetColori[j].name}: i temi '
              'della riga devono distinguersi a colpo d\'occhio',
        );
      }
    }
  });

  test('ogni colore regge la sua etichetta: onColor >= 4.5:1, chiaro e scuro',
      () {
    for (final entry in tabelle.entries) {
      for (final hex in entry.value) {
        final base = ColorResolver.hexToColor(hex)!;
        for (final brightness in Brightness.values) {
          final colore = brightness == Brightness.dark
              ? ColorResolver.darkVariant(base)
              : base;
          final ratio = ColorResolver.contrastRatio(
            colore,
            ColorResolver.onColor(colore),
          );
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '${entry.key} $hex ${brightness.name}');
        }
      }
    }
  });

  test('guardia anti-generatore: famigliaVicina non inventa colori', () {
    final ammesse = <String>{
      for (final colors in tabelle.values) ...colors,
    };
    // Tutto il giro della ruota, piu' i tre casi senza tinta.
    final semi = <String>[
      for (var gradi = 0.0; gradi < 360; gradi += 15) _hexDaTinta(gradi),
      '#808080',
      '#000000',
      '#ffffff',
    ];
    for (final seme in semi) {
      for (final colore in famigliaVicina(seme)) {
        expect(ammesse.contains(colore), isTrue,
            reason: '$colore (da «$seme») non sta nelle tabelle');
      }
    }
  });
}

/// Un hex saturo con la tinta data: serve solo a girare la ruota nel test.
String _hexDaTinta(double tinta) {
  final h = (tinta / 60) % 6;
  const c = 1.0;
  final x = c * (1 - ((h % 2) - 1).abs());
  final (double r, double g, double b) = switch (tinta) {
    < 60 => (c, x, 0.0),
    < 120 => (x, c, 0.0),
    < 180 => (0.0, c, x),
    < 240 => (0.0, x, c),
    < 300 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  String byte(double v) =>
      ((v + 0.0) * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${byte(r)}${byte(g)}${byte(b)}';
}
