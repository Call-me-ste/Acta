import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/ui/mobile/week_picker.dart';

/// Il risultato del foglio: il giorno scelto (o `null` se non si sceglie).
class _Esito {
  DateTime? giorno;
}

/// La scelta della settimana: un elenco di **intervalli** («8 – 14 set»), non un
/// numero — la settimana non ha un numero che si ricordi, ma un intervallo che si
/// riconosce a colpo d'occhio.
void main() {
  final esito = _Esito();

  /// Mercoledi' 16 settembre 2026, con «oggi» fissato al 17.
  Future<void> apri(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    esito.giorno = null;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  esito.giorno = await showWeekPicker(
                    context,
                    initial: DateTime(2026, 9, 16),
                    today: DateTime(2026, 9, 17),
                  );
                },
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'elenca le settimane che toccano il mese, con gli intervalli giusti',
      (tester) async {
    await apri(tester);

    // Settembre 2026 comincia di martedi': la prima settimana parte il 31 agosto e
    // l'ultima finisce il 4 ottobre.
    expect(find.text('31 ago – 6 set'), findsOneWidget);
    expect(find.text('7 – 13 set'), findsOneWidget);
    expect(find.text('14 – 20 set'), findsOneWidget);
    expect(find.text('21 – 27 set'), findsOneWidget);
    expect(find.text('28 set – 4 ott'), findsOneWidget);

    // La settimana che stai guardando e' segnata, ed e' anche quella di oggi.
    expect(find.text('oggi'), findsOneWidget);
  });

  testWidgets('toccare una settimana la sceglie e chiude', (tester) async {
    await apri(tester);

    await tester.tap(find.text('7 – 13 set'));
    await tester.pumpAndSettle();

    expect(esito.giorno, DateTime(2026, 9, 7));
    // Nessuna pillola di conferma: la riga **e'** la scelta.
    expect(find.textContaining('Vai a sett'), findsNothing);
    expect(find.text('Vai a'), findsNothing, reason: 'il foglio si e\' chiuso');
  });

  testWidgets('il mese si cambia dalle freccette', (tester) async {
    await apri(tester);

    expect(find.textContaining('Settembre 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Mese successivo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ottobre 2026'), findsOneWidget);
    // Ottobre 2026 comincia di giovedi': la prima settimana e' 28 set – 4 ott.
    expect(find.text('28 set – 4 ott'), findsOneWidget);
  });
}
