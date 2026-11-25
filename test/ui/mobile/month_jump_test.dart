import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/month_view.dart';

/// Il mese e l'anno si **toccano**: si apre l'elenco degli anni e dei mesi, e si
/// arriva a marzo 2027 in due tocchi invece che in sei freccette.
///
/// Si verifica anche quello che non deve cambiare: il **giorno scelto** resta
/// quello, perche' si sposta il vetro del calendario, non la selezione.
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

  Future<void> apri(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
  }

  DateTime giornoScelto(WidgetTester tester) => tester
      .widget<MonthView>(find.byType(MonthView, skipOffstage: false))
      .selectedDay;

  testWidgets('il titolo apre l\'elenco e porta la griglia al mese scelto',
      (tester) async {
    await apri(tester);

    // Il titolo dice dove siamo.
    expect(find.text('Settembre 2026'), findsOneWidget);

    await tester.tap(find.text('Settembre 2026'));
    await tester.pumpAndSettle();

    // L'elenco: la striscia degli anni (due secoli) e i dodici mesi.
    // I finder sono limitati al foglio: dietro resta l'intestazione del mese, che
    // dice lo stesso mese.
    Finder nelFoglio(Finder f) =>
        find.descendant(of: find.byType(BottomSheet), matching: f);
    expect(nelFoglio(find.text('Vai a')), findsOneWidget);

    // La striscia dichiara duecento anni, discreti: si tocca un anno, non si
    // "cade" fra due (era il difetto della rotella).
    final striscia = tester.widget<ListView>(
      find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(ListView)),
    );
    final delegato = striscia.childrenDelegate as SliverChildBuilderDelegate;
    expect(
      delegato.childCount,
      201,
      reason: 'dal 1900 al 2100: un elenco completo, non undici voci',
    );

    // Nessuna pillola di conferma: sarebbe ridondante, perche' toccare un mese
    // porta gia' a quel mese. Per cambiare **solo** l'anno si tocca lo stesso mese
    // nell'anno nuovo.
    expect(
      nelFoglio(find.textContaining('Vai a Settembre')),
      findsNothing,
      reason: 'la conferma in fondo era un doppione della griglia',
    );

    // Si tocca l'anno della striscia: i mesi restano quelli di quell'anno.
    await tester.tap(nelFoglio(find.text('2027')));
    await tester.pumpAndSettle();

    await tester.tap(nelFoglio(find.text('Mar')));
    await tester.pumpAndSettle();

    // Il titolo segue, e il giorno scelto non e' cambiato.
    expect(find.text('Marzo 2027'), findsOneWidget);
    expect(giornoScelto(tester), DateTime(2026, 9, 14));
  });

  testWidgets('le freccette cambiano mese e il titolo segue', (tester) async {
    await apri(tester);

    await tester.tap(find.byTooltip('Mese successivo'));
    await tester.pumpAndSettle();
    expect(find.text('Ottobre 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Mese precedente'));
    await tester.pumpAndSettle();
    expect(find.text('Settembre 2026'), findsOneWidget);
    expect(giornoScelto(tester), DateTime(2026, 9, 14));
  });

  testWidgets("l'anno sta su una riga sola, anche a testo ingrandito",
      (tester) async {
    await apri(tester);
    await tester.tap(find.text('Settembre 2026'));
    await tester.pumpAndSettle();

    // Altezza di una riga di testo: se l'anno andasse a capo sarebbe il doppio.
    final anno = tester.getSize(
      find.descendant(
          of: find.byType(BottomSheet), matching: find.text('2026')),
    );
    final riga = tester
        .getSize(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Vai a'),
          ),
        )
        .height;
    expect(
      anno.height,
      lessThan(riga * 1.8),
      reason: "l'anno deve stare su una riga, non spezzarsi in due",
    );
  });

  testWidgets("l'anno sta su una riga sola anche a testo ingrandito",
      (tester) async {
    // Il testo si ingrandisce **prima** di aprire: e' il caso del telefono
    // (caratteri di sistema a 1,3), ed e' la condizione in cui l'anno andava a capo.
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await apri(tester);

    await tester.tap(find.text('Settembre 2026'));
    await tester.pumpAndSettle();

    final anno = tester.getSize(
      find.descendant(
          of: find.byType(BottomSheet), matching: find.text('2026')),
    );
    final riga = tester
        .getSize(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Vai a'),
          ),
        )
        .height;
    expect(
      anno.height,
      lessThan(riga * 1.8),
      reason: "a 1,3 la voce deve crescere, non far andare l'anno a capo",
    );
  });
}
