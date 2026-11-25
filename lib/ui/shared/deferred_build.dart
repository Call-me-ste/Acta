import 'package:flutter/material.dart';

/// Costruisce il figlio **dopo il primo fotogramma**.
///
/// Serve alle sezioni lunghe che stanno sotto la piega, per esempio nel foglio
/// del form: il foglio si apre con un'animazione, e tutto quello che si costruisce
/// dentro quel primo fotogramma si paga nell'apertura. Quello che nessuno vede
/// ancora puo' aspettare un fotogramma: l'apertura resta leggera e il contenuto
/// c'e' comunque subito dopo.
///
/// Non e' un caricamento pigro vero e proprio (il figlio si costruisce un
/// fotogramma dopo, non quando entra nello schermo): e' il compromesso giusto per
/// un form, dove la sezione deve comunque esistere per raccogliere i dati.
class DeferredBuild extends StatefulWidget {
  const DeferredBuild({
    super.key,
    required this.child,
    this.placeholder = const SizedBox.shrink(),
  });

  final Widget child;

  /// Cosa mostrare nel frattempo: di serie niente, cosi' non si vede un salto.
  final Widget placeholder;

  @override
  State<DeferredBuild> createState() => _DeferredBuildState();
}

class _DeferredBuildState extends State<DeferredBuild> {
  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _pronto = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      _pronto ? widget.child : widget.placeholder;
}
