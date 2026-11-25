import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Lo scorrimento fra i mesi: **tre pagine, un dito, nessuno scorrimento di
/// sistema**.
///
/// Perché non una `PageView`, che sarebbe la scelta ovvia: mentre lo scorrimento
/// si assesta, la `PageView` **ignora i tocchi** — è il comportamento di
/// `Scrollable` (`BallisticScrollActivity.shouldIgnorePointer` è `true`) — e chi
/// scorre al mese dopo e tocca subito un giorno non viene ascoltato. È la
/// segnalazione dell'utente, ed è un difetto che si vede solo provandolo.
///
/// Qui il movimento lo guidiamo noi: il dito sposta le pagine, il rilascio le
/// assesta con un'animazione nostra, e **nessuno ignora niente**. Le tre pagine
/// (quella prima, quella che si guarda, quella dopo) sono costruite sempre, con
/// la chiave del loro mese: la griglia che entra esiste già, e il tocco che
/// arriva subito dopo trova un albero che non e' stato rifatto.
class MonthPager extends StatefulWidget {
  const MonthPager({
    super.key,
    required this.month,
    required this.animate,
    required this.onMonthChanged,
    required this.altezzaDelMese,
    required this.itemBuilder,
  });

  /// Il mese che si sta guardando.
  final DateTime month;

  /// Animazioni accese (preferenza o «riduci animazioni» di sistema). Si passa da
  /// fuori e non si legge qui: l'assestamento parte da un **gesto**, e in un
  /// gestore di evento iscriversi alle preferenze e' un'asserzione di provider.
  final bool animate;

  /// Un mese nuovo e' entrato in scena (scorrimento): la vista decide cosa farne.
  final ValueChanged<DateTime> onMonthChanged;

  /// Quanto e' alta la griglia di un mese: cinque o sei righe, e non tutte le
  /// griglie sono alte uguale.
  final double Function(DateTime month) altezzaDelMese;

  /// La pagina di un mese: la costruisce la vista, che sa quali dati chiedere e
  /// come tenerli caldi.
  final Widget Function(BuildContext context, DateTime month) itemBuilder;

  @override
  State<MonthPager> createState() => _MonthPagerState();
}

class _MonthPagerState extends State<MonthPager>
    with SingleTickerProviderStateMixin {
  /// Lo spostamento in **larghezze di pagina**: 0 = il mese a posto, positivo =
  /// il mese dopo che entra da destra (il dito va a sinistra).
  ///
  /// Le pagine si spostano per **layout** (`Positioned`), non con un
  /// `Transform` sul nastro: con la trasformazione il tocco durante
  /// l'assestamento non arrivava piu' alle griglie (verificato dai test), e il
  /// tocco e' la cosa che conta. Il costo di ricostruire le tre griglie a ogni
  /// evento del dito lo toglie la **memoria delle celle** (`MonthGrid`): quando
  /// niente cambia, i testi non si rimisurano.
  double _spostamento = 0;

  /// La larghezza di una pagina: la dice il `LayoutBuilder`.
  double _larghezza = 0;

  /// L'animazione dell'assestamento: da dove a dove.
  double _da = 0;
  double _a = 0;

  /// Vero quando il cambio di mese l'ha chiesto **questo** widget (lo
  /// scorrimento col dito): allora la pagina e' gia' quella giusta e non c'e'
  /// niente da far entrare.
  bool _cambioMio = false;

  /// Quanti mesi si tengono pronti: quello che si guarda e **uno per lato**.
  ///
  /// Era due, per fare in modo che il mese che entra all'assestamento esistesse
  /// già: allora la sua griglia si preparava (42 testi) nel fotogramma con il dito
  /// ancora giù. Adesso le celle stanno **fuori** dalla pagina
  /// (`CachePerMese`) e le prepara il precaricamento: la pagina che entra misura
  /// **0,01 ms** invece di 3,6 (profilato), quindi non serve tenerla viva — e ogni
  /// pagina in più è un elemento in più da aggiornare a ogni fotogramma di
  /// scorrimento.
  static const int _mesiPronti = 1;

  late final AnimationController _assesta;

  @override
  void initState() {
    super.initState();
    // Nel `initState` e non nel campo `late`: un `late` si crea alla prima
    // lettura, e se il widget viene smontato senza che nessuno lo abbia letto, a
    // crearlo sarebbe `dispose()` — su un elemento gia' staccato, dove guardare
    // `TickerMode` e' un'asserzione del framework.
    _assesta = AnimationController(vsync: this, duration: AppMotion.fast)
      ..addListener(_aggiorna);
  }

  @override
  void dispose() {
    _assesta.dispose();
    super.dispose();
  }

  void _aggiorna() {
    final t = AppMotion.curve.transform(_assesta.value);
    setState(() => _spostamento = _da + (_a - _da) * t);
  }

  @override
  void didUpdateWidget(MonthPager vecchio) {
    super.didUpdateWidget(vecchio);
    final cambiato = vecchio.month.year != widget.month.year ||
        vecchio.month.month != widget.month.month;
    if (!cambiato) return;

    // Il cambio viene dallo scorrimento: l'animazione e' appena finita e la
    // pagina e' gia' al suo posto.
    if (_cambioMio) {
      _cambioMio = false;
      return;
    }

    // Il mese e' cambiato **da fuori** — le frecce dell'intestazione, l'elenco
    // mese/anno — e la pagina nuova era gia' li': fino a ieri era un salto secco.
    // Adesso entra **come se fosse arrivata dal dito**, dal lato da cui viene: il
    // mese dopo da destra, quello prima da sinistra.
    //
    // Il verso e' l'opposto di quello dello scorrimento, perche' qui il mese e'
    // gia' cambiato: la pagina da mostrare e' quella **centrale** (a posto a
    // `_spostamento` zero), quindi si parte dall'altro capo — il mese vecchio e'
    // la pagina accanto, ed e' quella che deve uscire.
    _assesta.stop();
    final scarto = _scarto(vecchio.month, widget.month);
    setState(() => _spostamento = scarto > 0 ? -1.0 : 1.0);
    _assestaVerso(0);
  }

  /// Di quanti mesi sta [a] dopo [da] (negativo: prima).
  int _scarto(DateTime da, DateTime a) =>
      (a.year - da.year) * 12 + (a.month - da.month);

  void _trascina(DragUpdateDetails dettagli) {
    if (_larghezza == 0) return;
    _assesta.stop();
    setState(() {
      _spostamento =
          (_spostamento - dettagli.delta.dx / _larghezza).clamp(-1.0, 1.0);
    });
  }

  void _rilascia(DragEndDetails dettagli) {
    final velocita = dettagli.velocity.pixelsPerSecond.dx;
    // Si cambia mese se si e' passati **oltre meta' pagina**, o se il dito
    // scorreva deciso: e' la regola che ci si aspetta da una pila di pagine.
    final verso = _spostamento > 0.5 || velocita < -400
        ? 1
        : _spostamento < -0.5 || velocita > 400
            ? -1
            : 0;
    _assestaVerso(verso);
  }

  Future<void> _assestaVerso(int verso) async {
    _da = _spostamento;
    _a = verso.toDouble();

    _assesta.duration = widget.animate ? AppMotion.fast : Duration.zero;
    await _assesta.forward(from: 0);
    if (!mounted) return;

    if (verso == 0) {
      setState(() => _spostamento = 0);
      return;
    }

    // Il mese e' finito fuori schermo: si dice alla vista quale e' adesso, e si
    // riparte da zero — la pagina che era a +1 e' quella a posto adesso.
    final nuovo = DateTime(widget.month.year, widget.month.month + verso);
    setState(() => _spostamento = 0);
    _cambioMio = true;
    widget.onMonthChanged(nuovo);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, vincoli) {
        _larghezza = vincoli.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _trascina,
          onHorizontalDragEnd: _rilascia,
          child: ClipRect(
            child: Stack(
              children: [
                for (var scarto = -_mesiPronti; scarto <= _mesiPronti; scarto++)
                  _pagina(scarto),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Una pagina del nastro: il mese [scarto] mesi dopo quello guardato.
  ///
  /// La chiave sta **qui**, sul contenitore della pagina. Perché conta: il nastro
  /// è una lista di cinque pagine che scorrono, e senza chiave Flutter le
  /// riconoscerebbe **per posizione** — così, al cambio mese, la pagina che entra
  /// (da +2 al centro) sarebbe un elemento nuovo, con la sua griglia da
  /// riallineare: **cinque** pagine da 42 testi, ~19 ms in un fotogramma,
  /// misurati. Con la chiave l'elemento **segue la sua pagina**, e a rifarsi è
  /// solo quella che entra davvero dal bordo.
  Widget _pagina(int scarto) {
    final mese = DateTime(widget.month.year, widget.month.month + scarto);
    return Positioned(
      key: ValueKey('pagina-${mese.year}-${mese.month}'),
      left: (scarto - _spostamento) * _larghezza,
      top: 0,
      width: _larghezza,
      height: widget.altezzaDelMese(mese),
      // Fuori scena non si **dipinge**, ma resta nell'albero: con cinque pagine
      // pronte, ogni fotogramma dipingeva 210 celle al posto delle 42 che si
      // vedono (misurato: 7,8 ms di build per fotogramma di scorrimento).
      child: Offstage(
        offstage: (scarto - _spostamento).abs() >= 1,
        child: widget.itemBuilder(context, mese),
      ),
    );
  }
}
