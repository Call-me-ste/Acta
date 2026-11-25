import 'package:flutter/material.dart';

/// Una scheda del cambio vista: spostamento, offstage, ticker, sfondo, tocchi e
/// semantica. Estratta da `ViewPushSwitcher` per tenere quel file sotto le 300
/// righe e per lasciare la catena di wrapper **stabile** in un posto solo.
class VistaSpostata extends StatelessWidget {
  const VistaSpostata({
    super.key,
    required this.indice,
    required this.clock,
    required this.position,
    required this.inScena,
    required this.attiva,
    required this.child,
  });

  final int indice;
  final Animation<double>? clock;
  final double Function() position;
  final bool inScena;
  final bool attiva;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Offstage(
      offstage: !inScena,
      child: TickerMode(
        enabled: attiva,
        child: Material(
          // La chiave sta **dentro** lo spostamento: è questa scatola che si
          // muove, ed è questa che i test misurano.
          key: ValueKey('scheda-$indice'),
          // Il foglio è opaco: sotto non c'è niente da vedere. `Material` e non
          // `ColoredBox`: le viste contengono `ListTile`, che dipingono sfondo e
          // schizzi d'inchiostro sul `Material` più vicino.
          color: Theme.of(context).scaffoldBackgroundColor,
          child: IgnorePointer(
            ignoring: !attiva,
            child: ExcludeSemantics(
              excluding: !attiva,
              child: RepaintBoundary(child: child),
            ),
          ),
        ),
      ),
    );
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    Widget move(BuildContext context, Widget? child) => FractionalTranslation(
          translation: Offset(direction * position(), 0),
          child: child,
        );
    return ListenableBuilder(
      listenable: clock ?? kAlwaysCompleteAnimation,
      builder: move,
      child: surface,
    );
  }
}
