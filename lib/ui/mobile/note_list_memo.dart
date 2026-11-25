part of 'notes_page.dart';

class _NoteListMemo {
  List<Note>? _source;
  NoteOrdine? _order;
  ({String folder, String? tag, String query})? _filter;
  List<Note> _sorted = const [];
  List<Note> visible = const [];
  Map<String, int> tagCountsByName = const {};
  List<String> tags = const [];
  final _noteTags = Expando<Set<String>>();

  Set<String> _tagsOf(Note note) => _noteTags[note] ??= tagsOfNote(note);

  void update(
    List<Note> source,
    NoteOrdine order,
    ({String folder, String? tag, String query}) filter,
  ) {
    final changed = !identical(_source, source);
    if (changed) {
      _source = source;
      final counts = <String, int>{};
      for (final note in source) {
        for (final tag in _tagsOf(note)) {
          counts.update(tag, (count) => count + 1, ifAbsent: () => 1);
        }
      }
      tagCountsByName = counts;
      tags = counts.keys.toList()
        ..sort((a, b) {
          final count = counts[b]!.compareTo(counts[a]!);
          return count == 0 ? a.compareTo(b) : count;
        });
    }
    final reordered = changed || _order != order;
    if (reordered) {
      _order = order;
      _sorted = ordinaNote(source, order);
    }
    if (!reordered && _filter == filter) return;
    _filter = filter;
    visible = [
      for (final note in _sorted)
        if (_matches(note, filter)) note,
    ];
  }

  bool _matches(
      Note note, ({String folder, String? tag, String query}) filter) {
    final folder = switch (filter.folder) {
      'tutte' => true,
      'senza' => note.folderId == null,
      final id => note.folderId == id,
    };
    return folder &&
        (filter.tag == null || _tagsOf(note).contains(filter.tag)) &&
        (filter.query.isEmpty ||
            note.title.toLowerCase().contains(filter.query) ||
            note.content.toLowerCase().contains(filter.query));
  }
}
