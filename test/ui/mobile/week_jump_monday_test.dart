import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/day_header.dart';
import 'package:planner/ui/mobile/month_picker_cells.dart';
import 'package:planner/ui/mobile/week_nav_bar.dart';
import 'package:planner/ui/mobile/week_view.dart';

/// Passando alla settimana successiva la vista deve ripartire dal **lunedi'**,
/// non dal giorno che era selezionato prima.
///
/// Il motivo e' la coerenza del movimento: le frecce spostano *una settimana*, e
/// una settimana comincia di lunedi'. Prima la vista restava sulla colonna del
/// giorno scelto (giovedi' → giovedi'), quindi la settimana nuova si apriva a
/// meta'.
///
/// Cambia **solo** il salto di settimana: dentro la stessa settimana la regola
/// resta quella di prima (il giorno scelto va a sinistra quando c'e' posto), e la
/// prima apertura resta sul giorno scelto.
void main() {
  const gutter = AppSpacing.hourGutter;
  const larghezzaTela = 400.0;
  const giorniVisibili = WeekView.visibleDays;
  const colonna = (larghezzaTela - gutter) / giorniVisibili;

  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Future<void> apri(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
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
        // Giovedi' 17 settembre 2026: un giorno a meta' settimana, che e' il caso
        // in cui la differenza si vede.
        child: MaterialApp(
          home: CalendarPage(initialDay: DateTime(2026, 9, 17)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();
  }

  List<double> offsetOrizzontali(WidgetTester tester) {
    final pannelli = tester.widgetList<SingleChildScrollView>(
      find.descendant(
        of: find.byType(WeekView, skipOffstage: false),
        matching: find.byType(SingleChildScrollView, skipOffstage: false),
      ),
    );
    return [
      for (final pannello in pannelli)
        if (pannello.scrollDirection == Axis.horizontal)
          pannello.controller!.offset,
    ];
  }

  testWidgets('aprendo la settimana il giorno scelto e\' a sinistra',
      (tester) async {
    await apri(tester);

    // Giovedi' e' la quarta colonna: tre colonne di scorrimento, come richiesto
    // (e come verificato sul telefono).
    expect(offsetOrizzontali(tester), isNotEmpty);
    for (final offset in offsetOrizzontali(tester)) {
      expect(offset, closeTo(3 * colonna, 0.5));
    }
  });

  testWidgets('alla settimana dopo si riparte dal lunedi\'', (tester) async {
    await apri(tester);
    expect(offsetOrizzontali(tester).first, closeTo(3 * colonna, 0.5));

    await tester.tap(find.byTooltip('Settimana successiva'));
    await tester.pumpAndSettle();

    for (final offset in offsetOrizzontali(tester)) {
      expect(
        offset,
        closeTo(0, 0.5),
        reason: 'la settimana nuova comincia di lunedi\', a sinistra',
      );
    }
  });

  testWidgets('anche tornando indietro si riparte dal lunedi\'',
      (tester) async {
    await apri(tester);

    await tester.tap(find.byTooltip('Settimana precedente'));
    await tester.pumpAndSettle();

    for (final offset in offsetOrizzontali(tester)) {
      expect(offset, closeTo(0, 0.5));
    }
  });

  /// Il giorno **selezionato** dopo il salto: non basta che la vista scorra, deve
  /// essere il lunedi' a essere scelto — altrimenti resta evidenziato il giovedi'
  /// di prima, che e' esattamente quello che l'utente vedeva.
  testWidgets('dopo la freccia il giorno selezionato e\' il lunedi\'',
      (tester) async {
    await apri(tester);

    await tester.tap(find.byTooltip('Settimana successiva'));
    await tester.pumpAndSettle();

    // La data si legge nella vista giorno, che e' l'unica a scriverla per esteso.
    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();
    expect(
      find.text('Lunedì 21 settembre'),
      findsOneWidget,
      reason: 'la settimana nuova si apre con il lunedi\' selezionato',
    );
  });

  testWidgets('scegliendo una settimana dall\'elenco si va al suo lunedi\'',
      (tester) async {
    await apri(tester);

    // Il titolo dell'intestazione apre l'elenco delle settimane.
    await tester.tap(
      find.descendant(
        of: find.byType(WeekNavBar),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();

    // Una settimana qualunque dell'elenco, diversa da quella di partenza.
    final righe = tester.widgetList<WeekRow>(find.byType(WeekRow)).toList();
    expect(righe.length, greaterThan(3));
    final scelta = righe[2].monday;
    await tester.tap(find.byType(WeekRow).at(2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();
    expect(
      find.text(DayHeader.titolo(scelta)),
      findsOneWidget,
      reason: 'la selezione e\' il lunedi\' della settimana scelta',
    );
  });
}
