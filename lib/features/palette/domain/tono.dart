import 'armonia.dart';
import 'palette.dart';

/// Il **tono** del tema: come si presenta la stessa famiglia di colore.
///
/// Non è un'altra palette e non crea righe: è una scelta per-device che si
/// applica sopra il colore attivo, come la luminosità sopra una foto. Così
/// «Rosso» resta un colore solo, e chi vuole una versione morbida non si
/// ritrova otto copie nella libreria.
enum TonoTema {
  naturale('Naturale', 'I colori come sono nati'),
  pastello('Pastello', 'Tinte morbide e chiare'),
  vivace('Vivace', 'Tinte intense e brillanti'),
  sobrio('Sobrio', 'Tinte discrete e profonde');

  const TonoTema(this.etichetta, this.descrizione);

  final String etichetta;
  final String descrizione;

  /// Il nome salvato torna enum; un valore sconosciuto (versione più nuova,
  /// preferenza rotta) ricade su [naturale] invece di bloccare l'avvio.
  static TonoTema daNome(String? raw) {
    for (final tono in values) {
      if (tono.name == raw) return tono;
    }
    return naturale;
  }
}

/// Applica [tono] a una palette: seme e colori degli elementi passano da HSL,
/// mantengono la **tinta** e cambiano solo saturazione e luminosità.
///
/// Le formule sono volutamente semplici e monotone: un colore più scuro resta
/// più scuro del suo vicino, quindi la famiglia non perde la sua scala.
///
/// I ruoli del **modo semplice** restano quelli scelti a mano: sono superficie e
/// testo, e trasformarli insieme al resto romperebbe il contrasto (un nero su
/// bianco diventerebbe grigio su grigio). Lì il tono non passa.
Palette applicaTono(Palette palette, TonoTema tono) {
  if (tono == TonoTema.naturale) return palette;

  return palette.copyWith(
    seedHex: _colore(palette.seedHex, tono),
    colors: [for (final colore in palette.colors) _colore(colore, tono)],
  );
}

String _colore(String hex, TonoTema tono) {
  final hsl = Armonia.hsl(hex);
  if (hsl == null) return hex;

  final (saturazione, luminosita) = switch (tono) {
    TonoTema.naturale => (hsl[1], hsl[2]),
    // Chiari e poco saturi: il colore resta riconoscibile, ma non grida.
    TonoTema.pastello => (hsl[1] * 0.55, 0.58 + hsl[2] * 0.25),
    // Più carichi e un filo più profondi: il colore prende corpo.
    TonoTema.vivace => (hsl[1] * 1.25 + 0.05, 0.30 + hsl[2] * 0.38),
    // Desaturati e raccolti: la stessa voce, sottovoce.
    TonoTema.sobrio => (hsl[1] * 0.40, 0.25 + hsl[2] * 0.40),
  };

  return Armonia.daHsl(
    hsl[0],
    saturazione.clamp(0.0, 1.0).toDouble(),
    luminosita.clamp(0.0, 1.0).toDouble(),
  );
}
