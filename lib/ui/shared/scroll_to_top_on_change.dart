import 'package:flutter/material.dart';

import 'date_math.dart';
import '../../theme/design_tokens.dart';

/// Riporta una pagina in cima quando **cambia il giorno (o il mese) guardato**.
///
/// Sta in un file suo perche' e' una regola con due casi che sembrano uguali e non
/// lo sono:
///
/// - **cambia il giorno o il mese** (tocco su una cella, scelta dall'elenco, comando
///   «torna a oggi»): la pagina va in cima, cosi' le celle di quel giorno si vedono
///   per intero e non resta una scorsa fatta altrove;
/// - **si scorre restando sullo stesso giorno**: non si tocca niente. Chi scorre sta
///   leggendo, e riportarlo su sarebbe una prepotenza.
///
/// Il riporto avviene **dopo il disegno**: cambiando mese la pagina si deve prima
/// disporre, altrimenti lo scorrimento punta a un'estensione che non esiste ancora.
class ScrollToTopOnChange {
  ScrollToTopOnChange(this._scroll);

  final ScrollController _scroll;

  DateTime? _giorno;
  DateTime? _mese;

  /// Da chiamare nel `build` della pagina, con i valori di adesso.
  void aggiorna({
    required DateTime selectedDay,
    required DateTime focusedDay,
    required bool animate,
  }) {
    final cambioGiorno =
        _giorno == null || dateOnly(_giorno!) != dateOnly(selectedDay);
    final cambioMese = _mese == null ||
        _mese!.year != focusedDay.year ||
        _mese!.month != focusedDay.month;
    if (!cambioGiorno && !cambioMese) return;

    _giorno = selectedDay;
    _mese = focusedDay;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (_scroll.offset == 0) return;
      if (animate) {
        _scroll.animateTo(
          0,
          // 360 ms e non 220: una pagina intera che torna in cima in 220 ms si
          // legge come uno scatto. La fluidita' non e' la fretta.
          duration: AppMotion.slow,
          curve: AppMotion.curve,
        );
      } else {
        _scroll.jumpTo(0);
      }
    });
  }
}
