import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/day_header.dart';
import 'package:planner/ui/mobile/month_picker_cells.dart';
import 'package:planner/ui/mobile/week_day_headers.dart';

/// Due scorciatoie di navigazione, chieste dall'utente:
///
/// 1. dalla **vista giorno**, toccando la data si apre lo **stesso elenco di
///    settimane** della vista settimana, e si salta a quella settimana (al suo
///    lunedì) invece di scegliere mese e anno — una schermata in meno da
///    imparare, e si salta dove serve;
/// 2. dalla **vista settimana**, il **tocco prolungato** su un giorno apre quel
///    giorno nella vista giorno, con la stessa funzione che usa la vista mese.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Future<void> apri(WidgetTester tester, {DateTime? giorno}) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
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
          home: CalendarPage(
            initialDay: giorno ?? DateTime(2026, 9, 17),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nella vista giorno la data apre l\'elenco delle settimane',
      (tester) async {
    await apri(tester);
    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();
    expect(find.text('Giovedì 17 settembre'), findsOneWidget);

    // Il titolo dell'intestazione apre l'elenco (lo stesso della vista settimana).
    await tester.tap(
      find.descendant(
        of: find.byType(DayHeader),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();

    final righe = tester.widgetList<WeekRow>(find.byType(WeekRow)).toList();
    expect(
      righe,
      isNotEmpty,
      reason: 'deve aprirsi l\'elenco delle settimane, non la scelta del mese',
    );

    // Una settimana diversa da quella di partenza: si va al suo lunedì. Si tocca
    // la **riga** e non il testo: il numero del giorno dentro l'etichetta non è un
    // testo a sé (è dentro «7-13 set»), e cercarlo così non trova niente.
    final indice = righe.indexWhere((riga) => riga.monday.day == 7);
    expect(indice, greaterThanOrEqualTo(0));
    final scelta = righe[indice].monday;
    await tester.ensureVisible(find.byType(WeekRow).at(indice));
    await tester.tap(find.byType(WeekRow).at(indice));
    await tester.pumpAndSettle();

    expect(find.text(DayHeader.titolo(scelta)), findsOneWidget);
  });

  testWidgets(
      'il tocco prolungato su un giorno della settimana apre quel giorno',
      (tester) async {
    await apri(tester);
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    // Sabato 19: si tiene premuto sulla data della sua colonna.
    await tester.longPress(
      find.descendant(
        of: find.byType(WeekDayHeaders),
        matching: find.text('19'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Sabato 19 settembre'),
      findsOneWidget,
      reason: 'il tocco prolungato porta in vista giorno, su quel giorno',
    );
  });
}
