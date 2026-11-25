import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/palette/domain/presets.dart';
import 'package:planner/theme/color_resolver.dart';
import 'package:planner/theme/event_palette.dart';

/// I colori degli elementi sono **standard**: non cambiano col tema e restano
/// leggibili. Questa prova blocca le due cose insieme.
void main() {
  test('la palette standard ha 16 tinte distinte e valide', () {
    expect(EventPalette.length, 16);
    final visti = <int>{};
    for (final hex in EventPalette.colors) {
      final colore = ColorResolver.hexToColor(hex);
      expect(colore, isNotNull, reason: 'hex non valido: $hex');
      expect(visti.add(colore!.toARGB32()), isTrue,
          reason: 'tinta duplicata: $hex');
    }
  });

  test('il colore dell\'elemento non dipende dalla palette del tema', () {
    final a = presetColori.first;
    final b = presetColori.last;
    for (var i = 0; i < EventPalette.length; i++) {
      final daA = ColorResolver.elementColor(
        palette: a,
        brightness: Brightness.light,
        index: i,
      );
      final daB = ColorResolver.elementColor(
        palette: b,
        brightness: Brightness.light,
        index: i,
      );
      expect(daA, daB, reason: 'la palette ha cambiato il colore $i');
    }
  });

  test('ogni tinta standard regge il testo scelto per contrasto', () {
    for (var i = 0; i < EventPalette.length; i++) {
      for (final brightness in Brightness.values) {
        final colore = ColorResolver.elementColor(
          brightness: brightness,
          index: i,
        );
        final rapporto = ColorResolver.contrastRatio(
          colore,
          ColorResolver.onColor(colore),
        );
        expect(
          rapporto,
          greaterThanOrEqualTo(4.5),
          reason: '${EventPalette.at(i)} ${brightness.name} -> $rapporto',
        );
      }
    }
  });
}
