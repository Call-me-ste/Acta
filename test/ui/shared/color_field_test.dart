import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/theme/color_resolver.dart';
import 'package:planner/ui/shared/color_field.dart';
import 'package:planner/ui/shared/color_controls.dart';
import 'package:planner/ui/shared/color_wheel.dart';

/// La **ruota** dei colori e la barra della luminosità, col nome del colore
/// scritto sopra: sono due modi di dire la stessa cosa, non due verità.
///
/// Il campo del codice colore non c'è piu' (passo 12): era una cosa da
/// sviluppatori in mezzo a una scelta che si fa guardando.
void main() {
  Future<void> pumpField(
    WidgetTester tester,
    void Function(String) onChanged, {
    String initial = '#3f51b5',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorField(initialHex: initial, onChanged: onChanged),
        ),
      ),
    );
  }
  testWidgets('non c e nessun campo da scrivere: il codice non si vede',
      (tester) async {
    await pumpField(tester, (_) {});

    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('la ruota riporta il colore scelto, e il nome cambia con lui',
      (tester) async {
    final seen = <String>[];
    await pumpField(tester, seen.add);
    final nomePrima = tester.widget<Text>(find.byType(Text).first).data;

    // Un tocco sulla ruota, in un punto che non è quello di partenza.
    final ruota = tester.getRect(find.byType(ColorWheel));
    await tester.tapAt(ruota.center + const Offset(0, -60));
    await tester.pump();

    expect(seen, isNotEmpty);
    expect(seen.last, isNot('#3f51b5'), reason: 'il colore è cambiato');
    expect(
      tester.widget<Text>(find.byType(Text).first).data,
      isNot(nomePrima),
      reason: 'il nome del colore racconta quello che si è scelto',
    );
  });



  testWidgets('un colore pronto imposta la ruota e resta modificabile',
      (tester) async {
    final seen = <String>[];
    await pumpField(tester, seen.add);

    await tester.tap(find.byKey(const ValueKey('pronto-#e57373')));
    await tester.pump();
    expect(seen.last, '#e57373');

    // E da lì si continua a girare: è il punto di avere una ruota invece di una
    // fila di pastiglie.
    final ruota = tester.getRect(find.byType(ColorWheel));
    await tester.tapAt(ruota.center + const Offset(0, -60));
    await tester.pump();
    expect(seen.last, isNot('#e57373'));
  });

  testWidgets('la barra della luminosità cambia il colore', (tester) async {
    final seen = <String>[];
    await pumpField(tester, seen.add);

    final barra = tester.getRect(find.byType(BarraLuminosita));
    await tester.tapAt(Offset(barra.left + barra.width * 0.9, barra.center.dy));
    await tester.pump();

    expect(seen, isNotEmpty);
    expect(
      HSLColor.fromColor(
        ColorResolver.hexToColor(seen.last)!,
      ).lightness,
      greaterThan(0.7),
    );
  });
}
