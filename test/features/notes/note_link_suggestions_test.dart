import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/notes/note_link_suggestions.dart';

void main() {
  const eventi = [
    LinkCandidate(
      entityType: 'event',
      id: 'e1',
      title: 'Dentista',
    ),
    LinkCandidate(
      entityType: 'event',
      id: 'e2',
      title: 'Riunione lavoro',
    ),
  ];
  const todo = [
    LinkCandidate(
      entityType: 'todo',
      id: 't1',
      title: 'Comprare latte',
    ),
  ];

  test('sceglie il todo che condivide più parole', () {
    final scelta = miglioreCollegamento(
      testo: 'Comprare latte e pane',
      candidati: [...eventi, ...todo],
    );

    expect(scelta, isNotNull);
    expect(scelta!.candidate.id, 't1');
    expect(scelta.score, 2);
  });

  test('sceglie l\'evento giusto per una parola specifica', () {
    final scelta = miglioreCollegamento(
      testo: 'Dentista martedì',
      candidati: [...eventi, ...todo],
    );

    expect(scelta!.candidate.id, 'e1');
  });

  test('senza parole in comune non suggerisce niente', () {
    final scelta = miglioreCollegamento(
      testo: 'Idee per il weekend',
      candidati: [...eventi, ...todo],
    );

    expect(scelta, isNull);
  });

  test('non suggerisce un elemento già collegato', () {
    final scelta = miglioreCollegamento(
      testo: 'Comprare latte',
      candidati: [...eventi, ...todo],
      giaCollegati: const ['todo|t1'],
    );

    expect(scelta, isNull);
  });
}
