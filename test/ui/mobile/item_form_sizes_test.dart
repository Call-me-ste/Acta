import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/ui/mobile/item_form.dart';
import 'package:planner/ui/mobile/item_type.dart';
import 'package:planner/ui/shared/picker_tile.dart';

import '../../support/theme_providers.dart';

/// Le **misure** del form: era la segnalazione «pulsanti grandi rispetto alle
/// scritte, incoerenza grafica». Qui si verificano le due cose che rendono un
/// form ordinato: ogni riga toccabile è alta almeno 48 dp, e la scala del testo
/// non fa traboccare niente.
///
/// Le stesse 48 dp sono il motivo per cui le misure stanno nei token: se
/// qualcuno rimette un `ListTile` da 56 px con icona 24 accanto a un'etichetta
/// piccola, il primo test cade.
void main() {
  late DatabaseService db;
  late EventProvider events;
  late TodoProvider todos;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  /// L'altezza della riga che contiene `cosa`: si misura il **bersaglio**
  /// toccabile, non il testo (che è alto quanto il carattere).
  double altezzaRiga(WidgetTester tester, Finder cosa) {
    return tester
        .getSize(
          find.ancestor(of: cosa, matching: find.byType(ConstrainedBox)).first,
        )
        .height;
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    ItemType type = ItemType.evento,
    Todo? todo,
    double scalaTesto = 1,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = scalaTesto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ...themeProviders(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ItemForm(type: type, day: DateTime(2026, 9, 14), todo: todo),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('le righe dei campi sono alte almeno 48', (tester) async {
    await pumpForm(tester);

    final righe = find.byType(PickerTile);
    // Giorno, Colore, Ripetizione, Promemoria, Suono.
    expect(righe, findsAtLeastNWidgets(5));
    for (var i = 0; i < righe.evaluate().length; i++) {
      expect(
        tester.getSize(righe.at(i)).height,
        greaterThanOrEqualTo(AppSpacing.touchTarget),
        reason: 'riga $i del form sotto i 48 dp',
      );
    }

    final giorno = tester.widget<PickerTile>(righe.first);
    expect(
      tester.widget<Text>(find.text(giorno.label)).style?.fontSize,
      tester
          .widget<Text>(find.descendant(
              of: righe.first, matching: find.text(giorno.value)))
          .style
          ?.fontSize,
    );
    final frecce = find.descendant(
      of: righe,
      matching: find.byIcon(Icons.chevron_right),
    );
    final bordo = tester.getCenter(frecce.first).dx;
    for (var i = 1; i < frecce.evaluate().length; i++) {
      expect(tester.getCenter(frecce.at(i)).dx, bordo);
    }

    // La riga dell'interruttore è una riga di campo come le altre.
    expect(
      altezzaRiga(tester, find.text('Tutto il giorno')),
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
  });

  testWidgets('Salva resta nella testata ed è alto come le righe',
      (tester) async {
    await pumpForm(tester);

    final salva = find.widgetWithText(FilledButton, 'Salva');
    expect(salva.hitTestable(), findsOneWidget);
    expect(find.text('Promemoria'), findsOneWidget);
    expect(find.text('Altri dettagli'), findsNothing);
    final misura = tester.getSize(salva);
    expect(misura.height, greaterThanOrEqualTo(AppSpacing.touchTarget));
    expect(tester.getCenter(salva).dy,
        lessThan(tester.getCenter(find.text('Titolo')).dy));
  });

  testWidgets('in modifica Elimina è alto 48 e resta sotto ai campi',
      (tester) async {
    await todos.addTodo(title: 'Vecchio');
    await pumpForm(tester, type: ItemType.todo, todo: todos.todos.single);

    expect(find.text('Elimina'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Elimina')).height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
    await tester.ensureVisible(find.text('Elimina'));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('Elimina')).dy,
      greaterThan(tester.getCenter(find.text('Salva')).dy),
    );
  });

  testWidgets('anche «Rimuovi scadenza» è alto 48', (tester) async {
    await pumpForm(tester, type: ItemType.todo);

    expect(find.text('Rimuovi scadenza'), findsOneWidget);
    expect(
      tester
          .getSize(find.widgetWithText(TextButton, 'Rimuovi scadenza'))
          .height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
  });

  testWidgets('Evento e To do restano leggibili a testo 2,0', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    for (final type in ItemType.values) {
      await pumpForm(tester, type: type, scalaTesto: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('Salva').hitTestable(), findsOneWidget);
      final righe = find.byType(PickerTile);
      for (var i = 0; i < righe.evaluate().length; i++) {
        expect(
          tester.getSize(righe.at(i)).height,
          greaterThanOrEqualTo(AppSpacing.touchTarget),
        );
      }
    }
  });
}
