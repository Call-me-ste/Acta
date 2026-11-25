import 'dart:math' as math;

/// La **matematica delle tinte**: conversioni RGB/HSL/hex e distanze.
///
/// Puro: hex dentro, hex fuori, **nessun import di Flutter**. La conversione
/// RGB <-> HSL sta qui sotto perche' quella di Flutter (`HSLColor`) e' nel
/// painting, e la logica di `features/` non deve dipendere dai widget
/// (`architecture_test` lo pretende). Il vantaggio collaterale: si prova senza
/// disegnare niente.
///
/// I colori degli elementi **non** si generano piu' da qui: gli scarti di
/// tinta (triade, complementare) **stonavano** — era la segnalazione. Oggi
/// vengono dalle tabelle a mano di `presets.dart`; qui resta la matematica per
/// misurare le distanze e riconoscere i colori. La guardia in
/// `famiglia_colori_test` impedisce a un generatore di rientrare.
class Armonia {
  const Armonia._();

  /// La **tinta** di un colore, in gradi (0-360). `null` se non e' un colore.
  static double? tinta(String hex) => hsl(hex)?.first;

  /// Quanti gradi distano due tinte, sul **giro corto** (350° e 10° distano 20,
  /// non 340). 360 se uno dei due non e' un colore: distanza massima, mai
  /// "vicini" per sbaglio.
  static double distanzaTinta(String a, String b) {
    final ta = tinta(a);
    final tb = tinta(b);
    if (ta == null || tb == null) return 360;
    final d = (ta - tb).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  /// La **luminosita'** di un colore (0-1). `null` se non e' un colore.
  static double? luminosita(String hex) => hsl(hex)?[2];

  /// Hue, saturazione e luminosita' di un colore `#rrggbb`: `[h, s, l]`, o
  /// `null` se non e' un colore.
  static List<double>? hsl(String hex) {
    final rgb = _rgb(hex);
    if (rgb == null) return null;
    final r = rgb[0] / 255;
    final g = rgb[1] / 255;
    final b = rgb[2] / 255;

    final massimo = math.max(r, math.max(g, b));
    final minimo = math.min(r, math.min(g, b));
    final l = (massimo + minimo) / 2;
    final delta = massimo - minimo;
    if (delta == 0) return [0, 0, l];

    final s =
        l > 0.5 ? delta / (2 - massimo - minimo) : delta / (massimo + minimo);
    final double h;
    if (massimo == r) {
      h = ((g - b) / delta) % 6;
    } else if (massimo == g) {
      h = (b - r) / delta + 2;
    } else {
      h = (r - g) / delta + 4;
    }
    final gradi = (h * 60) % 360;
    return [gradi < 0 ? gradi + 360 : gradi, s, l];
  }

  /// Da HSL (tinta in gradi, saturazione e luminosità 0-1) a `#rrggbb`.
  ///
  /// Serve ai **toni del tema** (Pastello, Vivace, Sobrio): sono una scelta
  /// dell'utente, non il vecchio generatore di famiglie. Il giro di tinta resta
  /// quello del colore di partenza; cambiano solo saturazione e luminosità.
  static String daHsl(double tinta, double saturazione, double luminosita) {
    final h = ((tinta % 360) + 360) % 360;
    final s = saturazione.clamp(0.0, 1.0).toDouble();
    final l = luminosita.clamp(0.0, 1.0).toDouble();
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = l - c / 2;

    final (r, g, b) = switch (h) {
      < 60 => (c, x, 0.0),
      < 120 => (x, c, 0.0),
      < 180 => (0.0, c, x),
      < 240 => (0.0, x, c),
      < 300 => (x, 0.0, c),
      _ => (c, 0.0, x),
    };

    String canale(double valore) =>
        ((valore + m) * 255).round().clamp(0, 255).toRadixString(16).padLeft(
              2,
              '0',
            );
    return '#${canale(r)}${canale(g)}${canale(b)}';
  }

  /// Da `#rrggbb` (o `#rgb`, con o senza cancelletto) a (r, g, b) 0..255.
  static List<int>? _rgb(String value) {
    final hex = _normalizzaHex(value);
    if (hex == null) return null;
    return [
      int.parse(hex.substring(1, 3), radix: 16),
      int.parse(hex.substring(3, 5), radix: 16),
      int.parse(hex.substring(5, 7), radix: 16),
    ];
  }

  /// `#rrggbb` in minuscolo, da `#rgb`, `#rrggbb`, con o senza cancelletto.
  /// `null` se non e' un colore.
  static String? _normalizzaHex(String value) {
    var testo = value.trim();
    if (testo.startsWith('#')) testo = testo.substring(1);
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(testo)) return null;
    if (testo.length == 3) {
      testo = '${testo[0]}${testo[0]}${testo[1]}${testo[1]}'
          '${testo[2]}${testo[2]}';
    }
    if (testo.length != 6) return null;
    return '#${testo.toLowerCase()}';
  }
}
