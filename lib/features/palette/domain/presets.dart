import 'armonia.dart';
import 'palette.dart';

/// I **colori curati**: otto temi completi, ognuno con i suoi otto colori degli
/// elementi **scelti a mano**.
///
/// Perché a mano: i colori generati per scarti di tinta (triade, complementare)
/// **stonavano** — era la segnalazione. Ogni famiglia è una scala tonale del
/// colore del tema più due vicini di tinta a ±28°: stessa voce, mai un colore
/// che grida contro gli altri.
///
/// I vincoli sono **misurati**, non a occhio (`famiglia_colori_test`): ogni
/// coppia di una famiglia si distingue (≥25° di tinta **o** ≥0.18 di
/// luminosità) e ogni colore regge la propria etichetta (`onColor` ≥ 4.5:1,
/// chiaro e scuro). Le tabelle qui sotto sono la **verità**: il test le
/// confronta valle per valore, così un generatore non può rientrare dalla
/// finestra.
///
/// Gli id sono deterministici (`colore-rosso`, …): ogni device li crea identici
/// al primo avvio, quindi il sync non li trasporta e non si duplicano quando i
/// due dispositivi si incontrano.
const List<Palette> presetColori = [
  Palette(
    id: 'colore-rosso',
    name: 'Rosso',
    seedHex: '#D32F2F',
    isPreset: true,
    colors: [
      '#7E1B1B',
      '#D43535',
      '#E89292',
      '#A51D5C',
      '#E25A9A',
      '#F1D0DF',
      '#A55C1D',
      '#E29A5A',
    ],
  ),
  Palette(
    id: 'colore-arancione',
    name: 'Arancione',
    seedHex: '#F57C00',
    isPreset: true,
    colors: [
      '#7E4D1B',
      '#D48635',
      '#E8BD92',
      '#A5221D',
      '#E2605A',
      '#F1D1D0',
      '#A5A11D',
      '#E2DE5A',
    ],
  ),
  Palette(
    id: 'colore-giallo',
    name: 'Giallo',
    seedHex: '#F4EA34',
    isPreset: true,
    colors: [
      '#7E791B',
      '#D4CC35',
      '#E8E392',
      '#A55E1D',
      '#E29C5A',
      '#F1E0D0',
      '#6CA51D',
      '#AAE25A',
    ],
  ),
  Palette(
    id: 'colore-verde',
    name: 'Verde',
    seedHex: '#43A047',
    isPreset: true,
    colors: [
      '#1B7E1F',
      '#35D43C',
      '#92E895',
      '#57A51D',
      '#94E25A',
      '#DEF1D0',
      '#1DA562',
      '#5AE29F',
    ],
  ),
  Palette(
    id: 'colore-turchese',
    name: 'Turchese',
    seedHex: '#00ACC1',
    isPreset: true,
    colors: [
      '#1B737E',
      '#35C3D4',
      '#92DEE8',
      '#1DA574',
      '#5AE2B1',
      '#D0F1E5',
      '#1D57A5',
      '#5A94E2',
    ],
  ),
  Palette(
    id: 'colore-blu',
    name: 'Blu',
    seedHex: '#1A65D5',
    isPreset: true,
    colors: [
      '#1B437E',
      '#3575D4',
      '#92B4E8',
      '#1D93A5',
      '#5AD0E2',
      '#D0EDF1',
      '#261DA5',
      '#635AE2',
    ],
  ),
  Palette(
    id: 'colore-viola',
    name: 'Viola',
    seedHex: '#7B1FA2',
    isPreset: true,
    colors: [
      '#611B7E',
      '#A535D4',
      '#CE92E8',
      '#3D1DA5',
      '#7A5AE2',
      '#D8D0F1',
      '#A51D8E',
      '#E25ACB',
    ],
  ),
  Palette(
    id: 'colore-rosa',
    name: 'Rosa',
    seedHex: '#EC3C94',
    isPreset: true,
    colors: [
      '#7E1B4D',
      '#D43585',
      '#E892BD',
      '#A51DA0',
      '#E25ADD',
      '#F1D0F0',
      '#A51D22',
      '#E25A5F',
    ],
  ),
];

/// La famiglia **neutro**: grigi caldi e freddi. È il rifugio dei colori
/// scelti a mano senza tinta leggibile (nero, bianco, grigio): lì la vicinanza
/// di tinta non significa niente e servono colori che non stonano con nessun
/// tema. Non è un tema dell'elenco: non ha un seme, ha solo colori degli
/// elementi.
const List<String> famigliaNeutro = [
  '#372C25',
  '#816756',
  '#B8A599',
  '#E5DFDC',
  '#2C333A',
  '#637483',
  '#A9B3BC',
  '#E3E6E8',
];

/// **Tutti** i pronti: un solo gruppo, la riga del foglio del colore.
List<Palette> get presetTutti => presetColori;

/// La palette di partenza, per un database vuoto o per un id che non esiste più.
/// Blu: il più vicino al tema che l'app aveva prima delle palette.
const String defaultPaletteId = 'colore-blu';

/// `true` se il colore non ha una tinta leggibile (nero, bianco, grigio):
/// sotto il 12% di saturazione la tinta è rumore, non voce.
bool _acromatico(String hex) {
  final hsl = Armonia.hsl(hex);
  return hsl == null || hsl[1] < 0.12;
}

/// Il tema curato più vicino a [hex]: prima la **tinta** (giro corto), in
/// spareggio la luminosità. Senza tinta — o per un colore illeggibile —
/// vince la luminosità, e un hex rotto ricade sul tema di partenza.
///
/// Serve due volte: per dare una famiglia a «Il mio colore» e per **migrare**
/// un tema vecchio che non c'è più (l'utente non si vede cambiare il tema sotto
/// il naso: passa al più simile).
Palette coloreVicino(String hex) {
  final hsl = Armonia.hsl(hex);
  final diPartenza =
      presetColori.firstWhere((palette) => palette.id == defaultPaletteId);
  if (hsl == null) return diPartenza;

  final acromatico = hsl[1] < 0.12;
  final lum = hsl[2];
  Palette? vicino;
  var distanzaTinta = 360.0;
  var distanzaLuce = 1.0;

  for (final palette in presetColori) {
    final dt = acromatico ? 360.0 : Armonia.distanzaTinta(hex, palette.seedHex);
    final dl =
        (lum - (Armonia.luminosita(palette.seedHex) ?? 0.5)).abs();
    if (vicino == null ||
        dt < distanzaTinta ||
        (dt == distanzaTinta && dl < distanzaLuce)) {
      vicino = palette;
      distanzaTinta = dt;
      distanzaLuce = dl;
    }
  }
  return vicino ?? diPartenza;
}

/// I colori degli elementi per un colore scelto a mano: la famiglia curata più
/// vicina, oppure i neutri se il colore non ha tinta. **Mai** colori calcolati:
/// o vengono dalle tabelle, o sono i neutri.
List<String> famigliaVicina(String hex) =>
    _acromatico(hex) ? famigliaNeutro : coloreVicino(hex).colors;
