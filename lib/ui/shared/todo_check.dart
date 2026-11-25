import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'motion.dart';

/// Il cerchio di spunta di un todo: disegnato da noi, **non** il `Checkbox` di
/// sistema.
///
/// Perche' non `Checkbox`: la sua forma squadrata e' quella dei moduli, mentre
/// qui la spunta deve leggersi come "fatto" a colpo d'occhio, e deve avere il
/// colore dell'elemento. In piu' il riempimento **anima**: quando l'elenco si
/// riordina subito dopo il tocco, la risposta visiva dice che il tocco e'
/// arrivato.
class TodoCheck extends StatelessWidget {
  const TodoCheck({
    super.key,
    required this.done,
    required this.onTap,
    this.color,
    this.size = 28,
  });

  final bool done;
  final VoidCallback onTap;

  /// Il colore dell'elemento; senza, quello d'accento del tema.
  final Color? color;

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final attivo = color ?? scheme.primary;
    final durata = animationsOn(context) ? AppMotion.fast : Duration.zero;

    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Fatto' : 'Da fare',
      child: InkResponse(
        onTap: onTap,
        radius: size,
        child: AnimatedContainer(
          duration: durata,
          curve: AppMotion.curve,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? attivo : Colors.transparent,
            border: Border.all(
              // Anello col colore dell'elemento anche **da fermo**: senza la
              // spunta (che e' solo da fatto) e con lo sfondo monocolore della
              // vista Todo, l'anello è l'unico posto dove il colore scelto si
              // vede. Dove il colore non c'è, resta l'anello del tema.
              color: done ? attivo : (color ?? scheme.outline),
              width: 2,
            ),
          ),
          child: AnimatedScale(
            duration: durata,
            curve: Curves.easeOutBack,
            scale: done ? 1 : 0,
            child: Icon(
              Icons.check,
              size: size * 0.6,
              // Il segno sopra il riempimento: il contrasto lo decide il colore
              // di partenza, non il bianco a caso.
              color: scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
