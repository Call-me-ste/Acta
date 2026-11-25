import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/notes/domain/note.dart';
import 'package:planner/features/notes/note_tags.dart';

void main() {
  test('legge i tag nel titolo e nel contenuto, normalizzati', () {
    final tags = tagsOf('Spesa #Casa\ncomprare #latte e #Casa');
    expect(tags, {'casa', 'latte'});
  });

  test('non scambia i titoli markdown per tag', () {
    expect(tagsOf('# Titolo\n## Sottotitolo'), isEmpty);
  });

  test('accetta trattini, underscore, numeri e accenti', () {
    expect(
      tagsOf('#lavoro-2026 #nota_1 #perché #città'),
      {'lavoro-2026', 'nota_1', 'perché', 'città'},
    );
  });

  test('un ancora in un URL non è un tag', () {
    expect(tagsOf('https://example.com/#sezione'), isEmpty);
  });

  test('conteggia una nota una volta per tag', () {
    const a = Note(id: 'a', title: 'Casa', content: '#casa #spesa');
    const b = Note(id: 'b', title: 'Lavoro', content: '#lavoro #casa');
    final counts = tagCounts([a, b]);
    expect(counts['casa'], 2);
    expect(counts['spesa'], 1);
    expect(counts['lavoro'], 1);
  });
}
