/// Il testo normalizzato per confrontare quello che l'utente scrive con i posti
/// già usati: minuscolo, **senza accenti**, spazi ridotti a uno.
///
/// Gli accenti si tolgono perché nessuno li scrive mentre cerca: chi cerca
/// «peru» deve trovare «Perù», chi scrive «Piazza Dante» deve trovarla anche se
/// in archivio è «piazza dantè». Le lettere italiane accentate si mappano una per
/// una: sono cinque, non serve una tabella Unicode.
String normalizedPlace(String value) {
  const accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };

  final lower = value.toLowerCase().trim();
  final out = StringBuffer();
  var space = false;
  for (final char in lower.split('')) {
    if (char == ' ' || char == '\t' || char == '\n') {
      space = out.isNotEmpty;
      continue;
    }
    if (space) {
      out.write(' ');
      space = false;
    }
    out.write(accents[char] ?? char);
  }
  return out.toString();
}

/// I suggerimenti dei posti già usati, mentre l'utente scrive la posizione.
///
/// Regole, in ordine di forza: chi **inizia** con quello che hai scritto viene
/// prima di chi lo **contiene**, che viene prima di chi ci **assomiglia** (le
/// lettere scritte compaiono in ordine: «pzadan» trova «Piazza Dante», e così un
/// refuso non ti fa perdere il posto già usato). I doppioni si tolgono ignorando
/// maiuscole e accenti. Il tetto è [max]: la tendina non deve coprire il form.
class PlaceSuggestions {
  const PlaceSuggestions._();

  /// Quanti suggerimenti al massimo. Quattro: si vedono tutti senza scorrere.
  static const int max = 4;

  static List<String> forQuery(
    String typed,
    Iterable<String> used, {
    int max = PlaceSuggestions.max,
  }) {
    final query = normalizedPlace(typed);
    if (query.isEmpty) return const [];

    final starts = <String>[];
    final contains = <String>[];
    final resembles = <String>[];
    final seen = <String>{};

    for (final place in used) {
      final name = normalizedPlace(place);
      if (name.isEmpty || !seen.add(name)) continue;

      if (name.startsWith(query)) {
        starts.add(place);
      } else if (name.contains(query)) {
        contains.add(place);
      } else if (_isSubsequence(query, name)) {
        resembles.add(place);
      }
    }

    return [...starts, ...contains, ...resembles].take(max).toList();
  }

  /// Se «questo posto» è già in archivio: con un posto conosciuto si sceglie
  /// quello, non se ne crea un doppione scritto in modo diverso.
  static bool isKnown(String typed, Iterable<String> used) {
    final query = normalizedPlace(typed);
    if (query.isEmpty) return false;
    return used.any((place) => normalizedPlace(place) == query);
  }

  /// Vero quando ha senso offrire «Crea …»: c'è qualcosa di scritto e non è già
  /// un posto conosciuto.
  static bool offersCreate(String typed, Iterable<String> used) {
    return normalizedPlace(typed).isNotEmpty && !isKnown(typed, used);
  }

  /// Le lettere di `query` compaiono in `name` nello stesso ordine.
  static bool _isSubsequence(String query, String name) {
    var index = 0;
    for (final char in name.split('')) {
      if (char == query[index]) {
        index++;
        if (index == query.length) return true;
      }
    }
    return false;
  }
}
