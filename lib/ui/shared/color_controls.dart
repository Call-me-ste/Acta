import 'package:flutter/material.dart';

import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';

/// Gli **altri comandi** del selettore, accanto alla ruota: la barra della
/// luminosità (che in una ruota a due dimensioni non ci sta) e i colori pronti,
/// per partire da qualcosa invece che dal vuoto.
///
/// Stanno in un file loro perché il file della ruota ha un tetto di righe, e
/// perché sono due comandi, non il disegno della ruota.
///
/// La barra della **luminosità**: nero a sinistra, il colore scelto in mezzo,
/// bianco a destra. Si trascina come la ruota.
class BarraLuminosita extends StatelessWidget {
  const BarraLuminosita({
    super.key,
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double lightness;
  final ValueChanged<double> onChanged;

  static const double altezza = 28;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pieno = HSLColor.fromAHSL(1, hue, saturation, 0.5).toColor();

    return Semantics(
      label: 'Luminosità',
      value: '${(lightness * 100).round()} per cento',
      child: LayoutBuilder(
        builder: (context, vincoli) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (dettagli) =>
              _scegli(dettagli.localPosition.dx, vincoli.maxWidth),
          onPanStart: (dettagli) =>
              _scegli(dettagli.localPosition.dx, vincoli.maxWidth),
          onPanUpdate: (dettagli) =>
              _scegli(dettagli.localPosition.dx, vincoli.maxWidth),
          child: Stack(
            children: [
              Container(
                height: altezza,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.bar),
                  border: Border.all(color: scheme.outlineVariant),
                  gradient: LinearGradient(
                    colors: [Colors.black, pieno, Colors.white],
                  ),
                ),
              ),
              Positioned(
                left: (vincoli.maxWidth * lightness)
                        .clamp(0.0, vincoli.maxWidth) -
                    10,
                top: 4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: HSLColor.fromAHSL(1, hue, saturation, lightness)
                        .toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scegli(double x, double larghezza) {
    if (larghezza <= 0) return;
    onChanged((x / larghezza).clamp(0.0, 1.0));
  }
}

/// I **colori pronti** del selettore: dodici tinte che coprono il giro, più i
/// neutri. Non sono la palette dell'app (quella si sceglie dalla pagina dei colori):
/// sono le scelte che si fanno più spesso quando si colora un elemento.
///
/// Toccarne uno imposta la ruota: il colore resta **modificabile** subito dopo, che
/// è il punto di avere una ruota invece di una fila di pastiglie.
const List<String> coloriPronti = [
  '#e57373',
  '#f06292',
  '#ba68c8',
  '#7986cb',
  '#64b5f6',
  '#4db6ac',
  '#81c784',
  '#ffd54f',
  '#ffb74d',
  '#ff8a65',
  '#8d6e63',
  '#9e9e9e',
];

/// La fila dei colori pronti: pallini tondi, uno per colore.
class ColoriPronti extends StatelessWidget {
  const ColoriPronti({super.key, required this.onScelto});

  final ValueChanged<Color> onScelto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Il colore si legge **una volta** con la stessa regola dell'app (un hex
    // scritto male non diventa un colore a caso, sparisce).
    final pronti = [
      for (final hex in coloriPronti)
        if (ColorResolver.hexToColor(hex) case final colore?)
          (hex: hex, colore: colore),
    ];

    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        for (final voce in pronti)
          Semantics(
            button: true,
            label: 'Colore ${voce.hex}',
            child: InkWell(
              key: ValueKey('pronto-${voce.hex}'),
              onTap: () => onScelto(voce.colore),
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: voce.colore,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outlineVariant),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
