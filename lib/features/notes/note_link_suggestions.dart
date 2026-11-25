/// Un candidato al collegamento: un evento o un todo con il suo titolo.
class LinkCandidate {
  const LinkCandidate({
    required this.entityType,
    required this.id,
    required this.title,
  });

  /// `event` oppure `todo`.
  final String entityType;
  final String id;
  final String title;

  String get key => '$entityType|$id';
}

/// Il suggerimento scelto: uno solo, quello con più parole in comune.
class LinkSuggestion {
  const LinkSuggestion({required this.candidate, required this.score});

  final LinkCandidate candidate;
  final int score;

  String get key => candidate.key;
}

/// Parole troppo comuni per dire qualcosa sul collegamento.
const Set<String> _stopwords = {
  'oggi',
  'domani',
  'ieri',
  'della',
  'delle',
  'degli',
  'dello',
  'questo',
  'questa',
  'quello',
  'quella',
  'sono',
  'essere',
  'avere',
  'fare',
  'andare',
  'con',
  'per',
  'del',
  'dei',
  'nel',
  'nella',
  'nota',
  'todo',
  'evento',
  'appuntamento',
  'impegno',
};

Set<String> _parole(String testo) {
  return {
    for (final parola in testo
        .toLowerCase()
        .split(RegExp(r'[^a-zàèéìòù0-9]+'))
        .where((p) => p.length >= 4 && !_stopwords.contains(p)))
      parola,
  };
}

/// Sceglie **un solo** candidato: quello che condivide più parole (almeno una)
/// con il testo della nota. A parità vince il titolo più corto, che di solito è
/// il più specifico.
LinkSuggestion? miglioreCollegamento({
  required String testo,
  required Iterable<LinkCandidate> candidati,
  Iterable<String> giaCollegati = const [],
}) {
  final paroleNota = _parole(testo);
  if (paroleNota.isEmpty) return null;
  final esclusi = giaCollegati.toSet();

  LinkSuggestion? migliore;
  for (final candidato in candidati) {
    if (esclusi.contains(candidato.key)) continue;
    final paroleTitolo = _parole(candidato.title);
    final punteggio = paroleNota.intersection(paroleTitolo).length;
    if (punteggio == 0) continue;
    final scelta = LinkSuggestion(candidate: candidato, score: punteggio);
    if (migliore == null ||
        scelta.score > migliore.score ||
        (scelta.score == migliore.score &&
            candidato.title.length < migliore.candidate.title.length)) {
      migliore = scelta;
    }
  }
  return migliore;
}
