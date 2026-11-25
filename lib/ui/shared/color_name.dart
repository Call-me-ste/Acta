import 'package:flutter/material.dart';

/// Il nome di un colore, in italiano: quello che si legge al posto del codice
/// esadecimale.
///
/// Il nome si **calcola** dal colore (tinta, saturazione, luminosita') e non da
/// una tabella di codici: cosi' vale per qualunque tinta, compresa quella scelta
/// a mano, e non c'e' un elenco da tenere aggiornato.
///
/// Le due parole in piu' ("chiaro", "scuro") servono dove due colori diversi
/// avrebbero lo stesso nome: un azzurro pallido e un azzurro pieno sono due
/// scelte diverse, e chi legge deve poterle distinguere.
String colorNameFor(Color color) {
  final hsl = HSLColor.fromColor(color);

  // Poco colore: e' una scala di grigi, non una tinta sbiadita.
  if (hsl.saturation < 0.12) {
    if (hsl.lightness >= 0.93) return 'Bianco';
    if (hsl.lightness <= 0.10) return 'Nero';
    if (hsl.lightness < 0.42) return 'Grigio scuro';
    if (hsl.lightness > 0.74) return 'Grigio chiaro';
    return 'Grigio';
  }

  // Marrone: e' un arancione scuro e poco acceso. Senza questa riga un
  // "marrone" verrebbe chiamato "arancione", che non e' quello che si vede.
  if (hsl.hue >= 10 &&
      hsl.hue < 45 &&
      hsl.lightness < 0.55 &&
      hsl.saturation < 0.55) {
    return hsl.lightness <= 0.18 ? 'Marrone scuro' : 'Marrone';
  }

  final nome = switch (hsl.hue) {
    < 12 => 'Rosso',
    < 40 => 'Arancione',
    < 62 => 'Giallo',
    < 80 => 'Verde lime',
    < 155 => 'Verde',
    < 185 => 'Turchese',
    < 215 => 'Azzurro',
    < 260 => 'Blu',
    // Viola fino a 300: il viola di Material (#9C27B0) sta a 291 e chiamarlo
    // "magenta" sarebbe una parola che nessuno userebbe per quel colore.
    < 300 => 'Viola',
    < 335 => 'Magenta',
    < 350 => 'Rosa',
    _ => 'Rosso',
  };

  if (hsl.lightness >= 0.85) return '$nome chiaro';
  if (hsl.lightness <= 0.18) return '$nome scuro';
  return nome;
}

/// Il nome del colore a partire dal suo codice (`#rrggbb`), con un ripiego
/// quando il codice non si legge.
String colorNameOfHex(String? hex, {String fallback = 'Colore'}) {
  final color = _hexToColor(hex);
  return color == null ? fallback : colorNameFor(color);
}

Color? _hexToColor(String? hex) {
  if (hex == null) return null;
  final pulito = hex.replaceFirst('#', '').trim();
  if (pulito.length != 6) return null;
  final valore = int.tryParse(pulito, radix: 16);
  return valore == null ? null : Color(0xFF000000 | valore);
}
