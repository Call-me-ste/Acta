import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/theme/design_tokens.dart';
import 'package:planner/ui/mobile/month_grid_cells.dart';

/// La cella del mese non deve raddoppiare quando il testo raddoppia: la riga
/// cresce quanto il contenuto (numero, barre, «+N»), non quanto la scala.
void main() {
  testWidgets('le misure del mese derivano dal contenuto a 1.0/1.3/2.0',
      (tester) async {
    for (final scala in [1.0, 1.3, 2.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = scala;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final stile = Theme.of(context).textTheme.bodyLarge!;
              final lineHeight =
                  MediaQuery.textScalerOf(context).scale(stile.fontSize ?? 16) *
                      (stile.height ?? 1.2);
              final misure = MisureMese.di(
                context,
                cellWidth: 360 / 7,
              );

              expect(
                misure.latoNumero,
                greaterThanOrEqualTo(lineHeight),
                reason: 'a scala $scala il numero verrebbe tagliato',
              );
              expect(
                misure.rowHeight,
                greaterThanOrEqualTo(AppSpacing.touchTarget),
                reason: 'il bersaglio del giorno resta almeno 48 dp',
              );
              expect(
                misure.rowHeight,
                lessThan(108),
                reason: 'a scala $scala la riga non deve raddoppiare',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
