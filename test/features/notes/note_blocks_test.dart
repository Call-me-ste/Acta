import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/notes/note_blocks.dart';

void main() {
  test('riconosce paragrafi, puntati, numerati e checkbox', () {
    final blocchi = parseNoteBlocks(
      'Titolo\n- [ ] latte\n- [x] pane\n- nota\n1. primo\n2. secondo',
    );

    expect(blocchi[0].kind, NoteBlockKind.paragraph);
    expect(blocchi[1].kind, NoteBlockKind.checkbox);
    expect(blocchi[1].text, 'latte');
    expect(blocchi[2].checked, isTrue);
    expect(blocchi[3].kind, NoteBlockKind.bullet);
    expect(blocchi[4].kind, NoteBlockKind.numbered);
    expect(blocchi[4].number, 1);
  });

  test('spuntare una checkbox cambia solo quella riga', () {
    const testo = 'Fare:\n- [ ] latte\n- [ ] pane';
    final nuovo = toggleCheckbox(testo, 1, true);

    expect(nuovo, 'Fare:\n- [x] latte\n- [ ] pane');
  });

  test('la toolbar sostituisce il marcatore della riga', () {
    const testo = 'Fare:\n- punto';
    final nuovo = prefissaRiga(testo, testo.length, '- [ ] ');

    expect(nuovo, 'Fare:\n- [ ] punto');
  });
}
