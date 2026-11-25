/// La cronologia dell'editor: stati serializzati, non blocchi.
///
/// Salvare il markdown invece dei widget tiene la memoria piccola e rende
/// l'annulla indipendente da come è fatto un blocco.
class NoteHistory {
  NoteHistory(String iniziale) {
    _stati.add(iniziale);
    _indice = 0;
  }

  static const int _massimo = 80;

  final List<String> _stati = [];
  int _indice = -1;

  bool get canUndo => _indice > 0;
  bool get canRedo => _indice < _stati.length - 1;

  void record(String stato) {
    if (_indice >= 0 && _stati[_indice] == stato) return;
    _stati.removeRange(_indice + 1, _stati.length);
    _stati.add(stato);
    if (_stati.length > _massimo) _stati.removeAt(0);
    _indice = _stati.length - 1;
  }

  String? undo() {
    if (!canUndo) return null;
    _indice -= 1;
    return _stati[_indice];
  }

  String? redo() {
    if (!canRedo) return null;
    _indice += 1;
    return _stati[_indice];
  }
}
