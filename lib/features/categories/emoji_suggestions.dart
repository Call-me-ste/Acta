/// Le emoji proposte dall'editor categoria: una manciata scelta a mano, più i
/// suggerimenti locali dal nome. Niente AI, niente rete: solo parole italiane.
const List<String> emojiChoices = [
  '📌',
  '🏠',
  '💼',
  '🎓',
  '❤️',
  '🏃',
  '🛒',
  '💰',
  '✈️',
  '🎉',
  '🐾',
  '📞',
  '🛠️',
  '🎵',
  '🍽️',
  '👨‍👩‍👧',
  '📚',
  '⚽',
  '💊',
  '🌱',
];

/// Parole italiane → emoji. L'ordine delle chiavi è l'ordine dei suggerimenti.
const Map<String, List<String>> _perParola = {
  'palestra': ['🏋️', '🏃', '💪', '⚽'],
  'sport': ['🏃', '⚽', '🏋️', '💪'],
  'allenamento': ['🏋️', '🏃', '💪'],
  'medico': ['🩺', '💊', '🏥', '❤️'],
  'dottore': ['🩺', '💊', '🏥'],
  'salute': ['🩺', '💊', '❤️', '🏥'],
  'farmacia': ['💊', '🩺'],
  'lavoro': ['💼', '📊', '📞'],
  'ufficio': ['💼', '📊', '📞'],
  'riunione': ['💼', '📞', '📊'],
  'studio': ['🎓', '📚', '📝'],
  'scuola': ['🎓', '📚', '📝'],
  'università': ['🎓', '📚', '📝'],
  'universita': ['🎓', '📚', '📝'],
  'esame': ['📝', '📚', '🎓'],
  'casa': ['🏠', '🧹', '🛒'],
  'pulizia': ['🧹', '🏠'],
  'spesa': ['🛒', '🏠'],
  'viaggio': ['✈️', '🧳', '🌍'],
  'vacanza': ['✈️', '🧳', '🌍'],
  'volo': ['✈️', '🧳'],
  'compleanno': ['🎂', '🎉', '🎁'],
  'festa': ['🎉', '🎂', '🎁'],
  'bolletta': ['💳', '🧾', '💰'],
  'bollette': ['💳', '🧾', '💰'],
  'pagamento': ['💳', '💰', '🧾'],
  'fattura': ['🧾', '💳', '💰'],
  'auto': ['🚗', '⛽', '🛠️'],
  'macchina': ['🚗', '⛽', '🛠️'],
  'benzina': ['⛽', '🚗'],
  'famiglia': ['👨‍👩‍👧', '🧸'],
  'bambini': ['🧸', '👨‍👩‍👧'],
  'figli': ['👨‍👩‍👧', '🧸'],
  'cena': ['🍽️', '🍕', '☕'],
  'pranzo': ['🍽️', '🍕', '☕'],
  'ristorante': ['🍽️', '🍕'],
  'musica': ['🎵', '🎧'],
  'concerto': ['🎵', '🎧'],
  'animali': ['🐾', '🐶', '🐱'],
  'gatto': ['🐱', '🐾'],
  'cane': ['🐶', '🐾'],
  'giardino': ['🌱', '🌿'],
  'piante': ['🌱', '🌿'],
  'telefono': ['📞'],
  'chiamare': ['📞'],
};

/// Fino a [max] emoji: prima le parole del nome, poi quelle già usate nelle
/// categorie, poi le proposte standard. Mai duplicati.
List<String> emojiSuggerite(
  String nome, {
  Iterable<String> recenti = const [],
  int max = 6,
}) {
  final testo = nome.toLowerCase();
  final out = <String>[];
  void aggiungi(String emoji) {
    if (emoji.isNotEmpty && !out.contains(emoji)) out.add(emoji);
  }

  for (final voce in _perParola.entries) {
    if (testo.contains(voce.key)) {
      for (final emoji in voce.value) {
        aggiungi(emoji);
      }
    }
  }
  for (final emoji in recenti) {
    aggiungi(emoji);
  }
  for (final emoji in emojiChoices) {
    aggiungi(emoji);
  }
  return out.take(max).toList();
}
