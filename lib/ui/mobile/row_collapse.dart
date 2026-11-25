import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../shared/motion.dart';

/// Una riga che, invece di sparire di colpo, si **chiude**: l'altezza va a zero
/// con una transizione breve.
///
/// Perché così e non con un `AnimatedSize` su tutta la fascia: quello, per
/// animare, deve costruire **tutte** le righe, anche quelle fuori schermo. Con i
/// 47 scaduti dei dati di prova erano **23 ms di build misurati** — ed è la
/// ragione per cui le righe sono *fratelli* della lista e non figlie di un
/// `Column`. Così se ne animano al massimo [RigaCheSiChiude.quante], e le altre
/// spariscono subito: non si vedono comunque.
///
/// Si anima **solo la chiusura** (è quella che si guarda: la fascia si richiude
/// sotto il dito). All'apertura le righe entrano subito, che è anche quello che
/// ci si aspetta da un tocco che apre qualcosa.
class RigaCheSiChiude extends StatelessWidget {
  const RigaCheSiChiude({super.key, required this.child});

  /// Quante righe si animano: quante ne stanno sullo schermo.
  static const int quante = 8;

  /// Quanto dura: il tempo di un respiro, non un'animazione da guardare. Dalla
  /// scala dei movimenti (`AppMotion`), non scritta qui: una durata a mano non
  /// segue le altre il giorno in cui si decide di rallentare tutto.
  static const Duration durata = AppMotion.fast;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Da 1 a 0: la riga c'è già, si sta togliendo.
      tween: Tween<double>(begin: 1, end: 0),
      duration: animationsOn(context) ? durata : Duration.zero,
      curve: AppMotion.curve,
      builder: (context, fattore, child) => ClipRect(
        // `Align` con `heightFactor`: l'altezza della riga moltiplicata per il
        // fattore. Non serve misurare niente, ed è quello che rende l'animazione
        // possibile senza costruire la fascia intera.
        child: Align(heightFactor: fattore, child: child),
      ),
      child: child,
    );
  }
}
