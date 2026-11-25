import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/palette/domain/palette.dart';
import 'package:planner/features/palette/domain/presets.dart';
import 'package:planner/theme/color_resolver.dart';

/// Una palette **scelta a mano**: serve a provare un colore che i preset non
/// hanno (qui un rosso acceso, quello della segnalazione).
Palette _libera(String seed) => Palette(
      id: 'libera',
      name: 'Libera',
      seedHex: seed,
      colors: const [],
    );

/// Il colore è personalizzabile, quindi il contrasto non può restare una
/// questione di gusto: qui si **misura**. Con un colore arbitrario (#ff69b4) e
/// due temi, "mi sembra leggibile" non è una risposta.
void main() {
  group('contrasto', () {
    test(
        'ogni colore di ogni preset è leggibile col suo onColor, chiaro e scuro',
        () {
      final offenders = <String>[];
      for (final palette in presetColori) {
        for (var index = 0; index < palette.colors.length; index++) {
          for (final brightness in Brightness.values) {
            final color = ColorResolver.elementColor(
              palette: palette,
              brightness: brightness,
              index: index,
            );
            final ratio = ColorResolver.contrastRatio(
              color,
              ColorResolver.onColor(color),
            );
            if (ratio < 4.5) {
              offenders.add(
                '${palette.id}[$index] ${brightness.name} '
                '${palette.colors[index]} -> ${ratio.toStringAsFixed(2)}:1',
              );
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Colori sotto la soglia AA di 4.5:1. Con la regola "fra bianco e '
            'nero scegli quello che contrasta di più" il minimo possibile è '
            '4.58:1, quindi una violazione significa che la regola non è stata '
            'applicata. Violazioni: $offenders',
      );
    });

    test('il colore scelto è il colore del tema, non una sua riduzione', () {
      for (final palette in [...presetColori, _libera('#ff2d2d')]) {
        final scelto = ColorResolver.hexToColor(palette.seedHex)!;
        for (final brightness in Brightness.values) {
          final scheme = ColorResolver.schemeFor(
            palette: palette,
            brightness: brightness,
          );
          final chiaro = brightness == Brightness.light;
          // In chiaro **esattamente** il colore scelto: `fromSeed` lo rideduceva,
          // e un rosso acceso diventava quasi un rosa (la segnalazione). In scuro
          // la stessa tinta schiarita quanto basta a leggerla sul fondo nero.
          expect(
            scheme.primary,
            chiaro ? scelto : ColorResolver.darkVariant(scelto),
            reason: 'primary deve essere il colore scelto — ${palette.id} '
                '${brightness.name}',
          );
          if (!chiaro) {
            expect(
              HSLColor.fromColor(scheme.primary).hue,
              closeTo(HSLColor.fromColor(scelto).hue, 2.0),
              reason: 'in scuro si schiarisce, non si cambia tinta',
            );
          }
          // E il testo sopra il colore scelto resta leggibile: si sceglie fra
          // bianco e nero, quindi il rapporto peggiore e' 4.58:1.
          expect(
            ColorResolver.contrastRatio(scheme.onPrimary, scheme.primary),
            greaterThanOrEqualTo(4.5),
            reason: 'onPrimary su primary — ${palette.id} ${brightness.name}',
          );
          // Il colore scelto si legge anche **sul fondo** dove il colore lo
          // decide l'app: in scuro si schiarisce apposta (lo usano titoli, icone,
          // il cerchio del giorno scelto: col colore vero stava a **2,4:1**).
          //
          // In chiaro no: il colore scelto **vince** com'e' — e' la richiesta —
          // quindi un rosso acceso usato come testo sul fondo bianco puo' stare
          // sotto AA (misurato: #ff2d2d 3,8:1). Il testo **sopra** il colore resta
          // leggibile in tutti e due i casi (si sceglie fra bianco e nero).
          if (!chiaro) {
            expect(
              ColorResolver.contrastRatio(scheme.primary, scheme.surface),
              greaterThanOrEqualTo(4.5),
              reason: 'primary sul fondo — ${palette.id} ${brightness.name}',
            );
          }
          // I ruoli attorno al colore scelto vengono da lui: il contenitore e'
          // la sua tinta, non quella ridisegnata da Material. Due gradi di
          // tolleranza: il giro HSL -> RGB a 8 bit -> HSL sposta la tinta di
          // poco, e su un colore tenue la quantizzazione pesa di piu'.
          expect(
            HSLColor.fromColor(scheme.primaryContainer).hue,
            closeTo(HSLColor.fromColor(scelto).hue, 2.0),
            reason: 'il contenitore è della stessa tinta — ${palette.id}',
          );
          expect(
            ColorResolver.contrastRatio(
              scheme.onPrimaryContainer,
              scheme.primaryContainer,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'onPrimaryContainer su primaryContainer — ${palette.id}',
          );
        }
      }
    });

    test('il tema generato dal seed tiene il contrasto dei suoi ruoli', () {
      for (final palette in presetColori) {
        for (final brightness in Brightness.values) {
          final scheme = ColorResolver.schemeFor(
            palette: palette,
            brightness: brightness,
          );
          expect(
            ColorResolver.contrastRatio(scheme.onPrimary, scheme.primary),
            greaterThanOrEqualTo(4.5),
            reason: 'onPrimary su primary — ${palette.id} ${brightness.name}',
          );
          expect(
            ColorResolver.contrastRatio(scheme.onSurface, scheme.surface),
            greaterThanOrEqualTo(4.5),
            reason: 'onSurface su surface — ${palette.id} ${brightness.name}',
          );
        }
      }
    });

    test('un colore libero chiaro resta com\'è anche in scuro', () {
      final palette = presetColori.first;

      final light = ColorResolver.elementColor(
        palette: palette,
        brightness: Brightness.light,
        customHex: '#ff69b4',
      );
      final dark = ColorResolver.elementColor(
        palette: palette,
        brightness: Brightness.dark,
        customHex: '#ff69b4',
      );

      expect(light, const Color(0xFFFF69B4));
      // #ff69b4 ha già luminosità HSL 0.71: schiarirlo ancora lo sbiadirebbe,
      // quindi in scuro resta identico. La visibilità è il contrasto, non la
      // luminosità in sé.
      expect(dark, const Color(0xFFFF69B4));
      expect(
        ColorResolver.contrastRatio(dark, ColorResolver.onColor(dark)),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('un colore libero scuro viene schiarito per il tema scuro', () {
      final palette = presetColori.first;

      final light = ColorResolver.elementColor(
        palette: palette,
        brightness: Brightness.light,
        customHex: '#8B0000',
      );
      final dark = ColorResolver.elementColor(
        palette: palette,
        brightness: Brightness.dark,
        customHex: '#8B0000',
      );

      expect(
        dark.computeLuminance(),
        greaterThan(light.computeLuminance()),
        reason: 'in scuro una tinta scura sparisce sul fondo',
      );
      expect(HSLColor.fromColor(dark).lightness, closeTo(0.70, 0.01));
    });
  });

  group('derivazione dei colori', () {
    test('è deterministica', () {
      const base = Color(0xFF7986CB);
      expect(ColorResolver.darkVariant(base), ColorResolver.darkVariant(base));
    });

    test('non schiarisce due volte un colore già chiaro', () {
      // #FFECB3 ha luminosità HSL 0.85, sopra la soglia di 0.70.
      const alreadyLight = Color(0xFFFFECB3);
      expect(ColorResolver.darkVariant(alreadyLight), alreadyLight);
    });

    test('mantiene la tinta', () {
      const base = Color(0xFF4DB6AC);
      final dark = ColorResolver.darkVariant(base);
      expect(
        HSLColor.fromColor(dark).hue,
        closeTo(HSLColor.fromColor(base).hue, 1.0),
      );
    });

    test('l\'indice è ciclico: togliere un colore non fa sparire un evento',
        () {
      final palette = presetColori.first;
      expect(
        palette.colorAt(palette.colors.length),
        palette.colorAt(0),
      );
      expect(palette.colorAt(-1), palette.colorAt(palette.colors.length - 1));
    });
  });

  group('agenda: il testo degli eventi', () {
    test('è uno solo per tema: nero nel chiaro, bianco nel scuro', () {
      expect(ColorResolver.agendaTesto(Brightness.light), Colors.black);
      expect(ColorResolver.agendaTesto(Brightness.dark), Colors.white);
    });

    test('ogni colore di ogni famiglia regge quel testo, chiaro e scuro', () {
      final famiglie = <List<String>>[
        for (final palette in presetColori) palette.colors,
        famigliaNeutro,
      ];
      final offenders = <String>[];
      for (final colori in famiglie) {
        for (final hex in colori) {
          final base = ColorResolver.hexToColor(hex)!;
          for (final brightness in Brightness.values) {
            final fondo = ColorResolver.agendaFondo(base, brightness);
            final ratio = ColorResolver.contrastRatio(
              fondo,
              ColorResolver.agendaTesto(brightness),
            );
            if (ratio < 4.5) {
              offenders
                  .add('$hex ${brightness.name} -> ${ratio.toStringAsFixed(2)}');
            }
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'fondi che non reggono il testo uniforme: $offenders');
    });

    test('un fondo già leggibile torna identico', () {
      // Nel chiaro il rosa chiaro basta al nero; nel scuro il blu scuro al bianco.
      expect(
        ColorResolver.agendaFondo(const Color(0xFFF1D0DF), Brightness.light),
        const Color(0xFFF1D0DF),
      );
      expect(
        ColorResolver.agendaFondo(const Color(0xFF1B437E), Brightness.dark),
        const Color(0xFF1B437E),
      );
    });

    test('quando si muove, si muove solo la luminosità', () {
      final base = ColorResolver.hexToColor('#1B437E')!;
      final fondo = ColorResolver.agendaFondo(base, Brightness.light);
      expect(fondo, isNot(base), reason: 'il blu scuro nel chiaro si schiarisce');
      expect(
        HSLColor.fromColor(fondo).hue,
        closeTo(HSLColor.fromColor(base).hue, 2.0),
        reason: 'si schiarisce, non si cambia tinta',
      );
    });
  });

  group('hex', () {
    test('accetta #rgb, #rrggbb e #aarrggbb, con o senza cancelletto', () {
      expect(ColorResolver.hexToColor('#f0a'), const Color(0xFFFF00AA));
      expect(ColorResolver.hexToColor('ff69b4'), const Color(0xFFFF69B4));
      expect(ColorResolver.hexToColor('#80FF69B4'), const Color(0x80FF69B4));
    });

    test('rifiuta quello che non è un colore', () {
      for (final invalid in ['', '#', '#12345', 'rosso', '#gggggg', null]) {
        expect(
          ColorResolver.hexToColor(invalid),
          isNull,
          reason: 'accettato per sbaglio: "$invalid"',
        );
      }
    });

    test('il giro hex -> colore -> hex non perde il valore', () {
      const color = Color(0xFFFF69B4);
      expect(
        ColorResolver.hexToColor(ColorResolver.colorToHex(color)),
        color,
      );
    });
  });
}
