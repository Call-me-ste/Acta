import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/palette/domain/palette.dart';
import 'event_palette.dart';

/// Da una palette ai colori veri.
///
/// Due cose distinte, e vanno tenute distinte:
/// * il **tema** nasce dal seed (`ColorScheme.fromSeed`) e produce due schemi
///   separati, chiaro e scuro — non si inverte il chiaro per fare lo scuro;
/// * il **colore di un elemento** è una tinta piena, che in scuro va schiarita,
///   altrimenti un pastello su fondo nero non si vede.
///
/// Tutto qui dentro è puro calcolo: nessun widget, quindi è verificabile con un
/// test che misura il contrasto invece di guardarlo a occhio.
class ColorResolver {
  const ColorResolver._();

  /// Il colore delle superfici e dei controlli, chiaro o scuro.
  ///
  /// Il colore **scelto** (il seed) e' anche il colore del tema: `fromSeed` lo
  /// rideduce con la sua mappatura dei toni — un rosso acceso diventa quasi un
  /// rosa, ed e' la segnalazione — quindi dopo la generazione `primary` si
  /// riporta al colore scelto, con i ruoli che ci stanno attorno ricavati da lui.
  /// Il resto dello schema (superfici, contorni, stati) resta quello che il seed
  /// sa fare: e' la parte che a mano verrebbe PEGGIO.
  static ColorScheme schemeFor({
    required Palette palette,
    required Brightness brightness,
  }) {
    final scelto = hexToColor(palette.seedHex) ?? _fallback;
    final scheme = ColorScheme.fromSeed(
      seedColor: scelto,
      brightness: brightness,
    );
    return _coloreScelto(_conColoriSemplici(scheme, palette), scelto);
  }

  /// Il colore scelto **com'e'**, applicato sopra lo schema generato.
  ///
  /// In chiaro `primary` e' esattamente il colore scelto (era la segnalazione:
  /// `fromSeed` lo rideduceva, un rosso acceso diventava quasi un rosa). In scuro
  /// si **schiarisce** quanto basta a leggerlo sul fondo nero — la stessa regola
  /// dei colori degli elementi ([darkVariant]), perche' senza di essa il titolo di
  /// una sezione in un tema scuro sta a **2,4:1** sul fondo (misurato): sotto la
  /// soglia AA. La tinta resta quella scelta: si schiarisce, non si desatura.
  ///
  /// Il testo sopra il colore si sceglie fra bianco e nero ([onColor], minimo
  /// 4.58:1), e il contenitore e' la stessa tinta resa tenue — luminosita' al lato
  /// chiaro in chiaro e al lato scuro in scuro, con la saturazione abbassata
  /// perche' un contenitore pieno di colore diventa una macchia. Stessa tinta,
  /// quindi il contenitore resta "suo".
  static ColorScheme _coloreScelto(ColorScheme scheme, Color scelto) {
    final chiaro = scheme.brightness == Brightness.light;
    final principale = chiaro ? scelto : darkVariant(scelto);
    final hsl = HSLColor.fromColor(principale);

    return scheme.copyWith(
      primary: principale,
      onPrimary: onColor(principale),
      primaryContainer: hsl
          .withSaturation(math.min(hsl.saturation, 0.55))
          .withLightness(chiaro ? 0.88 : 0.26)
          .toColor(),
      onPrimaryContainer: hsl.withLightness(chiaro ? 0.18 : 0.92).toColor(),
    );
  }

  /// I quattro colori del modo semplice, applicati **sopra** lo schema generato.
  ///
  /// Perche' sopra e non al posto suo: il seed sa fare le cose difficili — i
  /// contenitori, gli stati, il contrasto del testo sui pulsanti — e rifarle a
  /// mano sarebbe il modo piu' rapido per avere testo illeggibile su un pulsante.
  /// Qui si toccano solo i quattro ruoli che l'utente ha scelto: fondo, superfici,
  /// testo, accento.
  ///
  /// Valgono in chiaro **e** in scuro: sono quattro, non otto. Se un giorno
  /// serviranno separati, si raddoppiano le chiavi.
  ///
  /// Il ruolo `primary` non vince sul seed: il colore scelto **e'** il colore del
  /// tema (vedi [_coloreScelto]), quindi qui si toccano solo fondo, superfici e
  /// testo.
  static ColorScheme _conColoriSemplici(ColorScheme scheme, Palette palette) {
    Color? del(String ruolo) => hexToColor(palette.simpleColors[ruolo]);

    final fondo = del('surface');
    final superfici = del('surfaceContainer');
    final testo = del('onSurface');
    if (fondo == null && superfici == null && testo == null) return scheme;

    return scheme.copyWith(
      surface: fondo,
      surfaceContainerHighest: superfici,
      surfaceContainer: superfici,
      onSurface: testo,
    );
  }

  /// Il colore di un elemento: l'hex libero vince sull'indice **standard**.
  ///
  /// [palette] resta nel contratto per i chiamanti storici, ma non decide più il
  /// colore dell'elemento: quello viene da [EventPalette], uguale in ogni tema.
  static Color elementColor({
    Palette? palette,
    required Brightness brightness,
    int index = 0,
    String? customHex,
  }) {
    final base = hexToColor(customHex) ??
        hexToColor(EventPalette.at(index)) ??
        _fallback;
    return brightness == Brightness.dark ? darkVariant(base) : base;
  }

  /// La variante scura di una tinta: stessa tonalità e saturazione, luminosità
  /// portata ad almeno 0.70. È la soglia sotto la quale un colore "sparisce"
  /// sulle superfici scure di Material 3.
  static Color darkVariant(Color base) {
    final hsl = HSLColor.fromColor(base);
    if (hsl.lightness >= 0.70) return base;
    return hsl.withLightness(0.70).toColor();
  }

  /// Testo e icone sopra [background]: fra bianco e nero si sceglie quello che
  /// contrasta di più — con questa regola il rapporto peggiore possibile è
  /// 4.58:1, sopra la soglia AA di 4.5:1.
  static Color onColor(Color background) {
    return contrastRatio(background, Colors.white) >=
            contrastRatio(background, Colors.black)
        ? Colors.white
        : Colors.black;
  }

  /// Il testo degli eventi in Agenda: **uno solo per tema** — nero nel chiaro,
  /// bianco nel scuro. Prima si sceglieva per box ([onColor]) e fila dopo fila
  /// le scitte alternavano bianco e nero: era la segnalazione.
  static Color agendaTesto(Brightness brightness) =>
      brightness == Brightness.light ? Colors.black : Colors.white;

  /// Il fondo del box evento in Agenda: la **tinta resta quella dell'evento** e
  /// si muove solo la luminosità, se serve, per far leggere il testo uniforme
  /// (≥4.5:1, con margine sull'arrotondamento a 8 bit). Nel chiaro si schiarisce,
  /// nel scuro si scurisce: la luminanza cresce con la luminosità HSL, quindi il
  /// confine è unico e la ricerca binaria ci arriva in 24 passi — ben oltre
  /// l'errore di un byte. Un fondo già leggibile torna indietro identico.
  static Color agendaFondo(Color base, Brightness brightness) {
    final testo = agendaTesto(brightness);
    const soglia = 4.6; // AA è 4.5: il margine copre l'arrotondamento dei byte
    if (contrastRatio(base, testo) >= soglia) return base;

    final hsl = HSLColor.fromColor(base);
    final chiaro = brightness == Brightness.light;
    // Invariante: un lato fallisce e l'altro passa. Gli estremi si conoscono:
    // bianco con nero e nero con bianco superano sempre AA.
    var sotto = chiaro ? hsl.lightness : 0.0;
    var sopra = chiaro ? 1.0 : hsl.lightness;
    for (var i = 0; i < 24; i++) {
      final mezzo = (sotto + sopra) / 2;
      final candidato = hsl.withLightness(mezzo).toColor();
      final passa = contrastRatio(candidato, testo) >= soglia;
      // passa → il lato buono stringe: nel chiaro è in alto, nello scuro in
      // basso. Non passa → il lato cattivo avanza.
      if (passa == chiaro) {
        sopra = mezzo;
      } else {
        sotto = mezzo;
      }
    }
    return hsl.withLightness(chiaro ? sopra : sotto).toColor();
  }

  /// Rapporto di contrasto WCAG 2.1 (1:1 … 21:1).
  static double contrastRatio(Color a, Color b) {
    final first = a.computeLuminance();
    final second = b.computeLuminance();
    final lighter = first > second ? first : second;
    final darker = first > second ? second : first;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// `#rgb`, `#rrggbb` o `#aarrggbb`, con o senza cancelletto. `null` se non è
  /// un colore valido: il campo hex è libero, quindi l'input non è fidato.
  static Color? hexToColor(String? value) {
    if (value == null) return null;
    var text = value.trim();
    if (text.startsWith('#')) text = text.substring(1);
    if (text.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) return null;

    // Tre forme in ingresso, **una** in uscita: aarrggbb. Il caso a 3 cifre
    // raddoppia le cifre e aggiunge l'alpha; senza questo passaggio `#f0a`
    // veniva letto come 0x00ff00aa, cioè quasi trasparente (bug trovato dal
    // test, non a occhio).
    final argb = switch (text.length) {
      3 => 'ff${text[0]}${text[0]}${text[1]}${text[1]}${text[2]}${text[2]}',
      6 => 'ff$text',
      8 => text,
      _ => null,
    };
    if (argb == null) return null;

    final parsed = int.tryParse(argb, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  /// Il contrario di [hexToColor], per mostrare il colore scelto nel campo.
  static String colorToHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  static const Color _fallback = Color(0xFF3F51B5);
}
