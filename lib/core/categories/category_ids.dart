/// Gli id delle categorie di un elemento, come stanno nella colonna
/// `category_ids`.
///
/// Il tetto di [maxCategoriesPerItem] sta **qui** e non solo nell'interfaccia:
/// un record che arriva da un altro dispositivo (o da un backup vecchio) non
/// puo' portarne dieci, e chi legge non deve ricordarsi di controllarlo.
///
/// Il testo (`"id1,id2"`) e' quello che viaggia nel record di sync, quindi va
/// scritto in modo stabile: senza doppioni e nell'ordine scelto dall'utente.
library;

const int maxCategoriesPerItem = 3;

/// Codifica gli id per la colonna. Elenco vuoto = nessuna categoria.
String encodeCategoryIds(List<String> ids) {
  final unique = <String>[];
  for (final id in ids) {
    final clean = id.trim();
    if (clean.isEmpty || unique.contains(clean)) continue;
    unique.add(clean);
    if (unique.length == maxCategoriesPerItem) break;
  }
  return unique.join(',');
}

/// L'inverso di [encodeCategoryIds], tollerante: un valore assurdo si scarta da
/// solo e il resto dell'elenco resta buono, che e' quello che serve quando il
/// record arriva da un altro dispositivo.
List<String> decodeCategoryIds(Object? raw) {
  if (raw == null) return const [];

  final ids = <String>[];
  for (final token in raw.toString().split(',')) {
    final clean = token.trim();
    if (clean.isEmpty || ids.contains(clean)) continue;
    ids.add(clean);
    if (ids.length == maxCategoriesPerItem) break;
  }
  return ids;
}
