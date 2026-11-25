import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/notes/domain/note.dart';
import 'package:planner/features/notes/domain/note_order.dart';

void main() {
  Note nota(String id, String titolo, {bool pinned = false, int? creato}) {
    return Note(
      id: id,
      title: titolo,
      pinned: pinned,
      createdAt:
          creato == null ? null : DateTime.fromMillisecondsSinceEpoch(creato),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(creato ?? 0),
    );
  }

  test('i pin restano in cima anche cambiando ordinamento', () {
    final note = [
      nota('a', 'Zeta', creato: 3),
      nota('b', 'Alfa', pinned: true, creato: 1),
      nota('c', 'Beta', creato: 2),
    ];

    final ordinate = ordinaNote(note, NoteOrdine.titolo);
    expect(ordinate.first.id, 'b');
    expect(ordinate.skip(1).map((n) => n.title), ['Beta', 'Zeta']);
  });

  test('ordina per titolo e per creazione', () {
    final note = [
      nota('a', 'Zeta', creato: 3),
      nota('b', 'Alfa', creato: 1),
      nota('c', 'Beta', creato: 2),
    ];

    expect(
      ordinaNote(note, NoteOrdine.titolo).map((n) => n.title),
      ['Alfa', 'Beta', 'Zeta'],
    );
    expect(
      ordinaNote(note, NoteOrdine.create).map((n) => n.title),
      ['Zeta', 'Beta', 'Alfa'],
    );
  });
}
