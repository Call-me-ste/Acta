import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/calendar/month_grid_geometry.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/month_view.dart';
import '../../support/grid.dart';

/// Il passaggio del giorno selezionato deve **muoversi**, non saltare: sia
/// toccando un giorno, sia tornando a oggi.
///
/// Prima la tinta del giorno scelto cambiava nello stesso fotogramma (un salto) e
/// lo scorrimento durava 220 ms: su mezza schermata si legge come uno scatto. Qui
/// si misura, non si guarda: un'animazione in corso e una pagina che a meta'
/// strada non e' ancora arrivata.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Widget harness() => MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: db),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
          ChangeNotifierProvider.value(
            value: AppSettingsController(db.settings)..load(),
          ),
          ChangeNotifierProvider.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
        ],
        child: MaterialApp(
          home: CalendarPage(initialDay: DateTime(2026, 9, 14)),
        ),
      );

  /// L'offset della pagina del mese (lo `CustomScrollView` della vista mese).
  double offset(WidgetTester tester) {
    final vista = find.descendant(
      of: find.byType(MonthView, skipOffstage: false),
      matching: find.byType(Scrollable),
    );
    return tester.state<ScrollableState>(vista.first).position.pixels;
  }

  Future<void> apri(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
  }

  testWidgets('toccando un giorno la tinta si accende, non salta',
      (tester) async {
    await apri(tester);

    // Un giorno dello **stesso** mese: cosi' non c'e' nessuno scorrimento di
    // mezzo (la griglia e' gia' in cima), e l'unica animazione della griglia e'
    // la tinta.
    await toccaGiorno(tester, DateTime(2026, 9, 21));
    await tester.pump();

    expect(
      tester.binding.transientCallbackCount,
      greaterThan(0),
      reason:
          'la tinta del giorno scelto deve animarsi, non comparire di colpo',
    );

    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('il cerchio si posa sul giorno toccato, e ci resta',
      (tester) async {
    await apri(tester);
    final mese = DateTime(2026, 9);
    final geometria = MonthGridGeometry(month: mese);

    await toccaGiorno(tester, DateTime(2026, 9, 21));
    await tester.pumpAndSettle();

    final acceso = [
      for (final giorno in disegnoDellaGriglia(tester, mese).giorni)
        if (giorno.evidenza > 0) giorno.indice,
    ];
    expect(
      acceso,
      [geometria.indiceDi(DateTime(2026, 9, 21))],
      reason: 'il cerchio del giorno scelto deve posarsi sul giorno toccato e '
          'restarci: prima l\'animazione lo portava li\' e poi tornava sul '
          'giorno di partenza (segnalato sul telefono)',
    );
  });

  testWidgets('tornando a oggi la griglia scorre invece di saltare',
      (tester) async {
    await apri(tester);

    await tester.drag(
      find.byType(MonthView, skipOffstage: false),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final partenza = offset(tester);
    expect(partenza, greaterThan(200), reason: 'la griglia deve essere scesa');

    await tester.tap(find.byTooltip('Torna a oggi'));
    // Tre fotogrammi, e servono tutti: il primo avvia l'animazione, il secondo
    // fa partire il suo cronometro (il primo tick ha tempo zero per definizione),
    // il terzo e' il tempo vero. Saltando il secondo la pagina risulta ferma.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 150));

    final aMeta = offset(tester);
    expect(
      aMeta,
      greaterThan(1),
      reason: 'a meta\' animazione la pagina non deve essere gia\' arrivata',
    );
    expect(aMeta, lessThan(partenza));

    await tester.pumpAndSettle();
    expect(offset(tester), 0);
  });
}
