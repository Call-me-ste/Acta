import 'package:flutter/material.dart';

import '../../features/palette/domain/palette.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';

/// La **casella** con cui si sceglie un colore: la tinta, un contenuto dentro e il
/// nome sotto.
///
/// Una classe sola per le due caselle del foglio — un colore pronto e «il mio
/// colore» — perche' sono la stessa cosa con due contenuti diversi: stesso
/// riquadro, stessa misura, stesso tocco. Cambia solo il bordo: spesso per il
/// tema che si sta guardando, sottile per la casella che apre la ruota (li' non
/// c'e' una tinta da mostrare ma una scelta da fare).
class ColorBox extends StatelessWidget {
  const ColorBox({
    super.key,
    required this.colore,
    required this.contenuto,
    required this.etichetta,
    required this.onTap,
    this.attiva = false,
    this.conBordo = false,
  });

  final Color colore;
  final Widget contenuto;
  final String etichetta;
  final VoidCallback onTap;

  /// Vero per il tema che si sta guardando.
  final bool attiva;

  /// Vero per la casella che apre la ruota.
  final bool conBordo;

  /// La misura della casella: 56 px — un bersaglio comodo anche col testo
  /// ingrandito, e sette per riga su un telefono normale.
  static const double lato = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bordo = attiva
        ? Border.all(color: scheme.onSurface, width: 3)
        : conBordo
            ? Border.all(color: scheme.outline)
            : Border.all(color: Colors.transparent, width: 3);

    return Semantics(
      button: true,
      selected: attiva,
      label: etichetta,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: SizedBox(
          width: lato,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: lato,
                height: lato,
                decoration: BoxDecoration(
                  color: colore,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: bordo,
                ),
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: contenuto,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                etichetta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La **striscia** con tutti i colori degli elementi di una palette: dice che
/// una tinta non e' solo il colore del tema — porta con se' i colori di eventi
/// e todo. Erano tre pallini su otto (era la parte «incompleta»): adesso si
/// vedono tutti.
class ColorStrip extends StatelessWidget {
  const ColorStrip({super.key, required this.palette});

  final Palette palette;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      children: [
        for (var indice = 0; indice < palette.colors.length; indice++)
          Expanded(
            child: Container(
              height: 8,
              color: ColorResolver.elementColor(
                palette: palette,
                brightness: brightness,
                index: indice,
              ),
            ),
          ),
      ],
    );
  }
}
