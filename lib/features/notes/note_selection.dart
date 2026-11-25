import 'package:flutter/foundation.dart';

/// La selezione multipla delle note. Sta sopra il guscio perché il tasto
/// indietro deve poter chiudere la selezione invece di cambiare scheda.
class SelezioneDelleNote extends ChangeNotifier {
  final Set<String> _ids = {};

  bool get attiva => _ids.isNotEmpty;
  int get quanti => _ids.length;
  Set<String> get ids => Set.of(_ids);

  bool contiene(String id) => _ids.contains(id);

  void apri(String id) {
    _ids
      ..clear()
      ..add(id);
    notifyListeners();
  }

  void inverti(String id) {
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
  }

  void tutti(Iterable<String> ids) {
    _ids
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void chiudi() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }
}
