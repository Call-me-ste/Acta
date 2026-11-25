import 'note.dart';

enum NoteOrdine {
  aggiornate('Aggiornate'),
  titolo('Titolo'),
  create('Create');

  const NoteOrdine(this.label);

  final String label;
}

/// Pin prima di tutto, poi il criterio scelto. Una copia, così la lista del
/// provider non viene riordinata da chi guarda.
List<Note> ordinaNote(Iterable<Note> note, NoteOrdine ordine) {
  final out = [...note];
  out.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    switch (ordine) {
      case NoteOrdine.aggiornate:
        final ad = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final perData = bd.compareTo(ad);
        // A parità di istante (due note create nello stesso millisecondo) il
        // titolo dà un ordine stabile: senza, la lista cambia ordine da sola.
        return perData != 0
            ? perData
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case NoteOrdine.titolo:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case NoteOrdine.create:
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final perData = bd.compareTo(ad);
        return perData != 0
            ? perData
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    }
  });
  return out;
}
