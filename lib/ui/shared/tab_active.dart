import 'package:flutter/widgets.dart';

/// Dice a chi sta sotto se la sua scheda si sta **guardando**.
///
/// Nasce da una misura: il guscio tiene vive le schede visitate (`IndexedStack`),
/// ed e' quello che fa sopravvivere il loro stato al cambio scheda — ma vuol dire
/// anche che chi sta dietro la barra in basso continua a disegnarsi. Sul telefono,
/// un tocco su una card costava 26,4 ms di build per la griglia del mese che
/// nessuno stava guardando.
///
/// Manca un `TabActive` sopra? Il widget non e' dentro nessuna scheda (un test,
/// un foglio, una pagina aperta a parte) e si comporta come sempre: attivo. E' il
/// default che tiene i test esistenti onesti invece di finti verdi.
class TabActive extends InheritedWidget {
  const TabActive({super.key, required this.attivo, required super.child});

  /// Vero se la scheda che contiene [child] e' quella che si vede.
  final bool attivo;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabActive>()?.attivo ?? true;

  @override
  bool updateShouldNotify(TabActive oldWidget) => attivo != oldWidget.attivo;
}

/// Ricostruisce [builder] a ogni notifica dei [notifiers] — ma le notifiche
/// arrivano **solo mentre la scheda si guarda**.
///
/// Perche' non basta `context.watch` a meta' tempo: una dipendenza da un
/// `InheritedWidget`, in Flutter, **non si disdice**. `Provider.of(context)`
/// iscrive l'elemento al provider, e passare a `listen: false` non lo toglie:
/// l'elemento resta iscritto finche' non esce dall'albero — che e' esattamente
/// quello che non succede qui, perche' il guscio tiene vive le schede. Verificato
/// sul campo: con `watch`/`read` condizionale la scheda nascosta si ricostruiva
/// lo stesso (26,4 ms di build per un tocco). `addListener`/`removeListener`
/// invece si tolgono davvero, ed e' l'unica cosa che zittisce chi non si vede.
///
/// Chi usa questo widget legge i provider con `context.read` e **non** con
/// `watch`: l'ascolto lo tiene lui, e averlo in due posti vorrebbe dire non
/// poterlo togliere.
class AscoltatoriSeAttivo extends StatefulWidget {
  const AscoltatoriSeAttivo({
    super.key,
    required this.notifiers,
    required this.builder,
  });

  /// I `ChangeNotifier` da ascoltare: i provider dei dati di questa schermata.
  final List<Listenable> notifiers;

  final WidgetBuilder builder;

  @override
  State<AscoltatoriSeAttivo> createState() => _AscoltatoriSeAttivoState();
}

class _AscoltatoriSeAttivoState extends State<AscoltatoriSeAttivo> {
  /// Gli ascolti accesi **adesso**: [AscoltatoriSeAttivo.notifiers] se la scheda
  /// si guarda, niente se no.
  List<Listenable> _iscritti = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `TabActive.of` registra la dipendenza (e' l'unica che serve): al cambio di
    // scheda questo metodo torna a girare, e con esso l'iscrizione.
    _aggiornaIscrizioni();
  }

  @override
  void didUpdateWidget(AscoltatoriSeAttivo vecchio) {
    super.didUpdateWidget(vecchio);
    _aggiornaIscrizioni();
  }

  @override
  void dispose() {
    for (final notifier in _iscritti) {
      notifier.removeListener(_ricostruisci);
    }
    super.dispose();
  }

  void _ricostruisci() {
    if (mounted) setState(() {});
  }

  void _aggiornaIscrizioni() {
    for (final notifier in _iscritti) {
      notifier.removeListener(_ricostruisci);
    }
    _iscritti = TabActive.of(context) ? [...widget.notifiers] : const [];
    for (final notifier in _iscritti) {
      notifier.addListener(_ricostruisci);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
