part of 'note_provider.dart';

int _compareNotes(Note a, Note b) {
  if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
  return (b.updatedAt?.millisecondsSinceEpoch ?? 0)
      .compareTo(a.updatedAt?.millisecondsSinceEpoch ?? 0);
}

List<Note> _withNote(List<Note> source, String id, Note? note) {
  final notes = [
    for (final note in source)
      if (note.id != id) note
  ];
  if (note == null) return notes;
  var low = 0;
  var high = notes.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (_compareNotes(notes[middle], note) <= 0) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  notes.insert(low, note);
  return notes;
}
