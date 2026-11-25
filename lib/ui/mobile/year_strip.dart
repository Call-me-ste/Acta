import 'package:flutter/material.dart';

import 'month_picker_cells.dart';

/// La striscia degli anni, condivisa dai due fogli di scelta.
///
/// Una voce per anno, larga quanto serve (cresce con il testo): si tocca l'anno
/// che si vuole e la striscia si centra da sola su quello in vista all'apertura.
class YearStrip extends StatefulWidget {
  const YearStrip({
    super.key,
    required this.anno,
    required this.annoOggi,
    required this.onAnno,
  });

  final int anno;
  final int annoOggi;
  final ValueChanged<int> onAnno;

  @override
  State<YearStrip> createState() => _YearStripState();
}

class _YearStripState extends State<YearStrip> {
  static const double altezza = 64;

  late final ScrollController _striscia = ScrollController();

  static double _larghezza(BuildContext context) =>
      72 * MediaQuery.textScalerOf(context).scale(1);

  @override
  void initState() {
    super.initState();
    // Si centra **dopo il primo fotogramma**, quando la larghezza della voce e'
    // nota (dipende dalla scala del testo).
    WidgetsBinding.instance.addPostFrameCallback((_) => _centra(widget.anno));
  }

  @override
  void didUpdateWidget(YearStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anno != widget.anno) _centra(widget.anno);
  }

  void _centra(int anno) {
    if (!mounted || !_striscia.hasClients) return;
    final voce = _larghezza(context);
    final vista = _striscia.position.viewportDimension;
    final grezzo = (anno - firstYear) * voce - (vista - voce) / 2;
    _striscia.jumpTo(grezzo.clamp(0, _striscia.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _striscia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altezza,
      child: ListView.builder(
        controller: _striscia,
        scrollDirection: Axis.horizontal,
        itemExtent: _larghezza(context),
        itemCount: lastYear - firstYear + 1,
        itemBuilder: (context, indice) {
          final anno = firstYear + indice;
          return AnnoPill(
            anno: anno,
            scelto: anno == widget.anno,
            oggi: anno == widget.annoOggi,
            onTap: () => widget.onAnno(anno),
          );
        },
      ),
    );
  }
}

/// Il primo e l'ultimo anno che si possono scegliere: due secoli.
const int firstYear = 1900;
const int lastYear = 2100;
