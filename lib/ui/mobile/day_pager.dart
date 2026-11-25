import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// La `PageView` dei giorni, che **segue** il giorno scelto.
///
/// Il controller nasce con il giorno scelto in quel momento: se poi il giorno
/// cambia da fuori (tocco prolungato nel mese, un giorno della settimana, la
/// striscia dei todo), la pagina va portata lì — altrimenti la vista giorno si
/// aprirebbe su un giorno vecchio. Serviva poco prima (la vista giorno si
/// costruiva al momento del cambio) e serve adesso che resta viva: è un difetto
/// trovato dai test, non a occhio.
///
/// Vive in un file suo per il tetto delle 300 righe di `calendar_page.dart`
/// (test/architecture_test.dart): si estrae, non si alza il tetto.
class DayPager extends StatefulWidget {
  const DayPager({
    super.key,
    required this.selectedDay,
    required this.indexOf,
    required this.dayAt,
    required this.onDaySelected,
    required this.itemBuilder,
  });

  final DateTime selectedDay;
  final int Function(DateTime) indexOf;
  final DateTime Function(int) dayAt;
  final ValueChanged<DateTime> onDaySelected;
  final Widget Function(BuildContext context, DateTime day) itemBuilder;

  @override
  State<DayPager> createState() => _DayPagerState();
}

class _DayPagerState extends State<DayPager> {
  late final PageController _controller =
      PageController(initialPage: widget.indexOf(widget.selectedDay));

  @override
  void initState() {
    super.initState();
    // Se il giorno è cambiato **prima** che questa pagina esistesse, il
    // controller è nato con la data di allora: si controlla al primo disegno.
    _segui();
  }

  @override
  void didUpdateWidget(DayPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay) _segui();
  }

  /// Porta la pagina sul giorno scelto, se non c'è già.
  ///
  /// **Dopo il disegno**: `jumpToPage` muove uno scorrimento e chiama `setState`,
  /// e chiamarlo durante il `build` è una `markNeedsBuild` dentro il build —
  /// un'asserzione del framework, trovata dai test. Il controllo «ci sono già»
  /// evita salti inutili e rimbalzi con lo scorrimento del dito.
  void _segui() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final atteso = widget.indexOf(widget.selectedDay);
      if (_controller.page?.round() == atteso) return;
      _controller.jumpToPage(atteso);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      // Il giorno prima e quello dopo si costruiscono **prima** che il dito si
      // muova: senza, la prima scorruta paga la griglia di 24 ore dall'altra
      // parte. Le due opzioni vanno insieme (una cache senza scorrimento
      // implicito non è ammessa dall'API).
      allowImplicitScrolling: true,
      scrollCacheExtent: const ScrollCacheExtent.viewport(1),
      // Scorrere i giorni è il gesto che rende utile la vista: il giorno
      // selezionato segue, così tornando al mese si è lì.
      onPageChanged: (index) => widget.onDaySelected(widget.dayAt(index)),
      itemBuilder: (context, index) =>
          widget.itemBuilder(context, widget.dayAt(index)),
    );
  }
}
