import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../../features/calendar/month_grid_geometry.dart';
import '../shared/feedback.dart';

/// Lo strato che prende il tocco sulla griglia del mese.
///
/// Un `Listener` e non un `GestureDetector`, per due ragioni misurate sui casi
/// reali:
///
/// * la tinta si accende sul **dito giù**, non quando l'arena dei gesti si
///   decide — con lo scorrimento del mese che concorre, `onTapDown` arriverebbe
///   solo al rilascio (lo stesso difetto che aveva l'inchiostro di prima);
/// * un tocco **subito dopo uno scorrimento** arrivava al posto giusto e non
///   faceva niente: è la segnalazione dell'utente. Un `Listener` non partecipa
///   all'arena: vede il dito comunque, e decide da solo se era un tocco (entro il
///   passo del tocco, `kTouchSlop`).
///
/// Il tocco **prolungato** resta a un `GestureDetector`: è un gesto che il
/// riconoscitore deve arbitrare, e non si fa mentre si scorre.
///
/// Il disegno arriva da fuori (`child`) e riceve il giorno sotto il dito, così la
/// tinta la disegna il painter — che è l'unico che sa dove sono le celle.
class ToccoDelMese extends StatefulWidget {
  const ToccoDelMese({
    super.key,
    required this.geometria,
    required this.onDaySelected,
    required this.onOpenDay,
    required this.child,
  });

  final MonthGridGeometry geometria;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onOpenDay;
  final Widget Function(BuildContext context, int? premuto) child;

  @override
  State<ToccoDelMese> createState() => _ToccoDelMeseState();
}

class _ToccoDelMeseState extends State<ToccoDelMese> {
  /// Il giorno sotto il dito: la tinta che dice «ho sentito il tocco».
  int? _premuto;

  /// Dove il dito si è appoggiato: serve a spegnere la tinta quando si scorre.
  Offset? _partenza;

  /// Vero se il dito si è mosso oltre il passo del tocco: allora il rilascio
  /// **non** seleziona (era uno scorrimento).
  bool _mosso = false;

  void _spegni() {
    if (_premuto != null) setState(() => _premuto = null);
  }

  @override
  Widget build(BuildContext context) {
    final geometria = widget.geometria;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (evento) {
        _partenza = evento.localPosition;
        _mosso = false;
        final giorno = geometria.giornoSotto(evento.localPosition);
        if (giorno == null) return;
        setState(() => _premuto = geometria.indiceDi(giorno));
      },
      onPointerMove: (evento) {
        final partenza = _partenza;
        if (partenza == null || _mosso) return;
        if ((evento.localPosition - partenza).distance <= kTouchSlop) return;
        _mosso = true;
        _spegni();
      },
      onPointerUp: (_) {
        final partenza = _partenza;
        _partenza = null;
        _spegni();
        if (_mosso || partenza == null) return;

        final giorno = geometria.giornoSotto(partenza);
        if (giorno != null) widget.onDaySelected(giorno);
      },
      onPointerCancel: (_) {
        _partenza = null;
        _spegni();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (dettagli) {
          final giorno = geometria.giornoSotto(dettagli.localPosition);
          if (giorno == null) return;
          tickFeedback();
          widget.onOpenDay(giorno);
        },
        child: widget.child(context, _premuto),
      ),
    );
  }
}
