/// La memoria **per mese**: una chiave, una firma, un tetto, uno sfratto.
///
/// Perché esiste: la stessa politica serviva alle celle (i testi misurati) e alle
/// finestre (i dati), ed era scritta in due file — e il 18/09 lo **stesso difetto**
/// di sfratto è stato corretto in tutti e due nello stesso giorno. Una regola, un
/// posto.
library;

/// Una memoria di valori per mese, riconosciuti da una firma.
///
/// Chi la usa decide di cosa è fatta la firma (per le celle: dati, selezione,
/// stili; per le finestre: le generazioni dei provider e il giorno scelto): qui si
/// sa solo che se la firma cambia, il valore non vale più.
class CachePerMese<T> {
  /// Quante voci restano: le tre pagine pronte, i mesi che il precaricamento
  /// scalda e quelli che si stanno lasciando.
  ///
  /// Sono liste di paragrafi misurati (~100 KB l'una) o mappe di occorrenze:
  /// dieci mesi sono un mega, che è niente rispetto a rimisurare 42 testi nel
  /// fotogramma in cui c'è il dito.
  static const int massime = 10;

  final Map<int, ({Object firma, T valore})> _voci = {};

  /// Il valore di [mese]: quello di prima se la [firma] non è cambiata, altrimenti
  /// si prepara adesso con [prepara].
  ///
  /// Le voci **toccate tornano in fondo** e le vittime si prendono dalla testa: è
  /// un *least recently used*, e non è un dettaglio. Con l'ordine di inserimento
  /// capitava che a essere buttati fossero proprio i mesi preparati dal
  /// precaricamento — che sono i più vecchi e i più utili — e la pagina che entra
  /// dal bordo li rimisurava da capo: **3,6 ms** misurati in un fotogramma di
  /// scorrimento.
  T di({
    required DateTime mese,
    required Object firma,
    required T Function() prepara,
  }) {
    final chiave = mese.year * 12 + mese.month;
    final voce = _voci[chiave];
    if (voce != null && voce.firma == firma) {
      _voci
        ..remove(chiave)
        ..[chiave] = voce;
      return voce.valore;
    }

    final nuovo = prepara();
    if (_voci.length >= massime) _voci.remove(_voci.keys.first);
    _voci[chiave] = (firma: firma, valore: nuovo);
    return nuovo;
  }
}
