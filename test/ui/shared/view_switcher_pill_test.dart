import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/theme/design_tokens.dart';
import 'package:planner/ui/shared/view_switcher_pill.dart';

/// Il selettore a pillola: la scelta arriva al chiamante, la pastiglia si sposta
/// e con le animazioni spente il movimento è **zero** (non "più veloce").
void main() {
  Future<void> pumpPill(
    WidgetTester tester, {
    required bool animate,
    required ValueChanged<String> onChanged,
    String value = 'uno',
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewSwitcherPill<String>(
            entries: const [
              ViewSwitcherEntry(value: 'uno', label: 'Uno'),
              ViewSwitcherEntry(value: 'due', label: 'Due'),
              ViewSwitcherEntry(value: 'tre', label: 'Tre'),
            ],
            value: value,
            onChanged: onChanged,
            animate: animate,
          ),
        ),
      ),
    );
  }

  testWidgets('la scelta arriva al chiamante', (tester) async {
    String? chosen;
    await pumpPill(tester, animate: true, onChanged: (v) => chosen = v);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Due'));
    await tester.pumpAndSettle();

    expect(chosen, 'due');
  });

  testWidgets('la pastiglia si sposta sulla voce scelta', (tester) async {
    await pumpPill(tester, animate: true, onChanged: (_) {}, value: 'tre');
    await tester.pumpAndSettle();

    final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
    expect(slide.offset, const Offset(2, 0));
    expect(slide.duration, AppMotion.controlSelection);
    expect(slide.curve, AppMotion.controlCurve);
  });

  testWidgets('con le animazioni spente il movimento è zero', (tester) async {
    await pumpPill(tester, animate: false, onChanged: (_) {});
    await tester.pumpAndSettle();

    final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
    expect(slide.duration, Duration.zero);
  });

  testWidgets('la voce scelta è annunciata come selezionata', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPill(tester, animate: true, onChanged: (_) {}, value: 'due');
    await tester.pumpAndSettle();

    // `flagsCollection` è l'API corrente (hasFlag è deprecato da 3.32) e i suoi
    // flag sono a tre stati: sì, no, e "non specificato".
    final node = tester.getSemantics(find.text('Due'));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isSelected, Tristate.isTrue);

    final other = tester.getSemantics(find.text('Uno'));
    expect(other.flagsCollection.isSelected, Tristate.isFalse);
    handle.dispose();
  });
}
