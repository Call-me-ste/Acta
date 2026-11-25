import 'package:flutter/foundation.dart';

/// La **selezione multipla** dei todo: chi e' selezionato, e se la selezione e'
/// aperta (basta che ci sia qualcuno dentro).
///
/// Perche' un controller e non lo stato della pagina: il **tasto indietro** lo
/// gestisce il guscio, che sta *sopra* la pagina, e per chiudere la selezione
/// deve poterla vedere. Un `PopScope` in piu' nella pagina non basterebbe:
/// `ModalRoute.onPopInvokedWithResult` chiama l'`onPopInvoked` di **tutti** i
/// `PopScope` registrati sulla rotta, quindi il guscio uscirebbe dall'app
/// **mentre** la pagina chiude la selezione.
class SelezioneDeiTodo extends ChangeNotifier {
  final Set<String> _ids = {};

  /// C'e' qualcuno selezionato: la barra contestuale e' aperta.
  bool get attiva => _ids.isNotEmpty;

  /// Quanti sono: il numero che si legge nella barra.
  int get quanti => _ids.length;

  /// Gli id selezionati, per le azioni. Una **copia**: chi la riceve non deve
  /// poter cambiare la selezione senza passare da qui (e senza avvisare).
  Set<String> get ids => Set.of(_ids);

  /// Se un todo e' dentro la selezione: la riga lo mostra.
  bool contiene(String id) => _ids.contains(id);

  /// Apre la selezione con un todo dentro: e' il tocco prolungato.
  void apri(String id) {
    _ids
      ..clear()
      ..add(id);
    notifyListeners();
  }

  /// Mette dentro o fuori un todo: e' il tocco, quando la selezione e' aperta.
  void inverti(String id) {
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
  }

  /// Seleziona tutti quelli che si stanno vedendo.
  void tutti(Iterable<String> ids) {
    _ids
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  /// Chiude la selezione: la X, il tocco fuori, il tasto indietro.
  void chiudi() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }
}
