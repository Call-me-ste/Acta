import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/recurrence/domain/recurrence_rule.dart';
import 'package:planner/ui/shared/recurrence_field.dart';

/// Il preset "Ogni 2 settimane" è l'unico punto in cui l'INTERVAL è
/// raggiungibile dalla UI: il chip deve produrre la regola giusta e riconoscerla
/// al ritorno (modifica di un evento già salvato).
void main() {
  Future<void> pumpField(WidgetTester tester, RecurrenceRule? rule) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecurrenceField(
            rule: rule,
            anchor: DateTime(2026, 9, 14),
            // Il secondo test non tocca nulla: il callback non serve.
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('il preset produce una regola ogni 2 settimane', (tester) async {
    // Il campo si affida al parent per ri-passargli la regola scelta (così
    // l'etichetta derivata si aggiorna): l'harness fa lo stesso, come il form.
    RecurrenceRule? current;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RecurrenceField(
              rule: current,
              anchor: DateTime(2026, 9, 14),
              onChanged: (value) => setState(() => current = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('recurrence-biweekly')));
    await tester.pumpAndSettle();

    expect(current, isNotNull);
    expect(current!.frequency, RecurrenceFrequency.weekly);
    expect(current!.interval, 2);
    expect(current!.toRuleString(), 'FREQ=WEEKLY;INTERVAL=2');
    expect(find.text('ogni 2 settimane'), findsOneWidget);
  });

  testWidgets('una regola ogni 2 settimane risultera\' selezionata',
      (tester) async {
    await pumpField(tester, RecurrenceRule.tryParse('FREQ=WEEKLY;INTERVAL=2'));

    // La riga giusta è selezionata nell'elenco, con la spunta.
    expect(find.text('Ogni 2 settimane'), findsOneWidget);
    expect(find.byKey(const ValueKey('recurrence-biweekly')), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('la scelta è un elenco: niente chip affiancate', (tester) async {
    await pumpField(tester, null);

    expect(find.byType(ListTile), findsWidgets);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('i giorni personalizzati sono checkbox, non chip',
      (tester) async {
    await pumpField(tester, null);

    await tester.tap(find.byKey(const ValueKey('recurrence-custom')));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsNWidgets(7));
    expect(find.byType(FilterChip), findsNothing);
  });
}
