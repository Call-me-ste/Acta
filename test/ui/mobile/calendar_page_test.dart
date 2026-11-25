import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/day_section.dart';
import 'package:planner/ui/mobile/month_grid.dart';
import 'package:planner/ui/mobile/week_view.dart';

import '../../support/finders.dart';
import '../../support/grid.dart';
import '../../support/theme_providers.dart';

/// La pagina legge le **occorrenze del giorno** (eventi e ricorrenze): prima
/// mostrava *tutti* gli eventi del database, in qualunque giorno fossero.
void main() {
  late DatabaseService db;
  late EventProvider provider;
  late TodoProvider todos;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    provider = EventProvider(db);
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  Future<void> pumpPage(WidgetTester tester, DateTime day) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: provider),
          // La vista mese ora conta anche i todo nelle celle: senza il provider
          // il sottoalbero esplode con ProviderNotFoundException.
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          // La pagina disegna i colori degli eventi, quindi le serve la palette
          // attiva e le preferenze: senza, ProviderNotFoundException.
          ...themeProviders(db),
        ],
        child: MaterialApp(home: CalendarPage(initialDay: day)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedTwoDays() async {
    await provider.addEvent(
      title: 'Dentista',
      start: DateTime(2026, 9, 13, 9),
      end: DateTime(2026, 9, 13, 10),
    );
    await provider.addEvent(
      title: 'Riunione',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    );
  }

  testWidgets('la lista mostra solo gli eventi del giorno selezionato',
      (tester) async {
    await seedTwoDays();
    await pumpPage(tester, DateTime(2026, 9, 13));

    expect(calendarFinder, findsOneWidget);
    expect(find.text('Dentista'), findsOneWidget);
    expect(find.text('Riunione'), findsNothing);
  });

  testWidgets('cambiando giorno cambia la lista', (tester) async {
    await seedTwoDays();
    await pumpPage(tester, DateTime(2026, 9, 13));

    await toccaGiorno(tester, DateTime(2026, 9, 14));
    await tester.pumpAndSettle();

    expect(find.text('Riunione'), findsOneWidget);
    expect(find.text('Dentista'), findsNothing);
  });

  testWidgets('un giorno senza eventi mostra lo stato vuoto', (tester) async {
    await seedTwoDays();
    await pumpPage(tester, DateTime(2026, 9, 15));

    expect(find.text('Nessun evento in questo giorno'), findsOneWidget);
    expect(find.text('Dentista'), findsNothing);
  });

  testWidgets('due tocchi rapidi mese-settimana-giorno: vince il giorno',
      (tester) async {
    await seedTwoDays();
    await pumpPage(tester, DateTime(2026, 9, 14));

    // Due tap veri sulla pillola, ravvicinati: la seconda scelta non deve
    // aspettare i 320 ms della prima.
    await tester.tap(find.text('Settimana'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('Giorno'));
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.byType(DaySection), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(DaySection), findsOneWidget);
    expect(find.byType(WeekView), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a testo 2.0 la vista giorno non trabocca', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seedTwoDays();
    await pumpPage(tester, DateTime(2026, 9, 14));

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    expect(find.byType(DaySection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con il testo ingrandito le sigle dei giorni non sono tagliate',
      (tester) async {
    // Il telefono dell'utente ha textScaler 1.15: table_calendar riserva 16 px
    // fissi alla riga dei giorni, quindi le sigle (14 px con height 1.4) finivano
    // tagliate in basso. La condizione che rende il taglio impossibile è che il
    // contenitore sia alto almeno quanto il testo: qui si misura, non si spera.
    tester.platformDispatcher.textScaleFactorTestValue = 1.15;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpPage(tester, DateTime(2026, 9, 14));

    // Le sigle le disegna il painter: quello che si puo' verificare — ed e' la
    // cosa che conta — e' che la fascia in cima sia **alta almeno quanto il
    // testo**, che era il difetto (16 px fissi tagliavano le sigle in basso).
    final griglia = tester.widget<MonthGrid>(find.byType(MonthGrid).first);
    final stile = Theme.of(tester.element(find.byType(MonthGrid).first))
        .textTheme
        .labelSmall!;
    final sigla = TextPainter(
      text: TextSpan(text: 'mer', style: stile),
      textDirection: TextDirection.ltr,
    )..layout();

    expect(
      griglia.headerHeight,
      greaterThanOrEqualTo(sigla.height),
      reason: 'sigla tagliata: fascia ${griglia.headerHeight} px, '
          'testo ${sigla.height} px',
    );
  });
}
