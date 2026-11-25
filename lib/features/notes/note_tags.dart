import 'domain/note.dart';

/// I tag della Note, stile Apple: `#lavoro` nel titolo o nel testo.
///
/// Non c'è una tabella: i tag si **derivano** dal contenuto, quindi viaggiano
/// già nel campo `content` del sync e non serve una migrazione.
final RegExp _tag = RegExp(
  r'(?:^|[\s(])#([0-9A-Za-zÀ-ÖØ-öø-ÿ_-]+)',
);

/// I tag di un testo, normalizzati in minuscolo e senza doppioni.
Set<String> tagsOf(String testo) {
  final trovati = <String>{};
  for (final match in _tag.allMatches(testo)) {
    final valore = match.group(1);
    if (valore != null && valore.isNotEmpty) {
      trovati.add(valore.toLowerCase());
    }
  }
  return trovati;
}

/// I tag di una nota: titolo e contenuto, entrambi.
Set<String> tagsOfNote(Note note) => tagsOf('${note.title}\n${note.content}');

/// Quante note usano ogni tag (una nota conta una volta sola per tag).
Map<String, int> tagCounts(Iterable<Note> note) {
  final conteggi = <String, int>{};
  for (final n in note) {
    for (final tag in tagsOfNote(n)) {
      conteggi[tag] = (conteggi[tag] ?? 0) + 1;
    }
  }
  return conteggi;
}
