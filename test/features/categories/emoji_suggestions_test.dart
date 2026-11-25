import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/categories/emoji_suggestions.dart';

/// Il motore emoji è locale e deterministico: parole italiane, recenti, tetto 6.
void main() {
  test('palestra suggerisce emoji di sport, senza duplicati', () {
    final emoji = emojiSuggerite('Palestra');
    expect(emoji, contains('🏋️'));
    expect(emoji.length, lessThanOrEqualTo(6));
    expect(emoji.toSet().length, emoji.length);
  });

  test('medico suggerisce salute, non sport', () {
    final emoji = emojiSuggerite('Visita medico');
    expect(emoji, contains('🩺'));
    expect(emoji, isNot(contains('🏋️')));
  });

  test('le recenti entrano nei suggerimenti', () {
    final emoji = emojiSuggerite('xyz', recenti: ['🎯']);
    expect(emoji, contains('🎯'));
    expect(emoji.length, lessThanOrEqualTo(6));
  });

  test('è case-insensitive e non supera mai sei', () {
    expect(emojiSuggerite('LAVORO'), contains('💼'));
    expect(emojiSuggerite('casa lavoro studio', max: 4).length, 4);
  });
}
