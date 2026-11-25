import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:provider/provider.dart';

/// La richiesta di aprire il calendario su **un giorno preciso**, arrivata da
/// fuori dall'albero dei widget (il pacchetto del mese toccato sulla schermata
/// home: `planner://apri?giorno=2026-09-24`).
///
/// Perché una richiesta e non un parametro: quel tocco può arrivare mentre
/// l'app è chiusa (allora è l'URI di avvio) o mentre è aperta su un'altra
/// scheda, e il calendario può non esistere ancora. La richiesta resta qui
/// finché la pagina non la consuma, così l'ordine fra «la scheda si costruisce»
/// e «il giorno è scelto» non conta.
class GiornoRichiesto extends ChangeNotifier {
  DateTime? _giorno;

  /// Il giorno chiesto, se c'è ancora.
  DateTime? get giorno => _giorno;

  void chiedi(DateTime giorno) {
    _giorno = DateTime(giorno.year, giorno.month, giorno.day);
    notifyListeners();
  }

  /// Prende la richiesta e la toglie: la pagina la applica una volta sola.
  DateTime? consuma() {
    final giorno = _giorno;
    _giorno = null;
    return giorno;
  }
}

/// La richiesta, se l'app l'ha montata.
///
/// Non è pigrizia: la pagina del calendario si prova da sola nei test (`23`
/// file la montano senza il guscio dell'app), e un `Provider` che manca lì non
/// deve far esplodere venti prove che non c'entrano col widget. È la stessa
/// scelta (e la stessa forma) di `filtroAttivo` per il filtro condiviso.
GiornoRichiesto? giornoRichiestoDi(BuildContext context) =>
    context.read<GiornoRichiesto?>();
