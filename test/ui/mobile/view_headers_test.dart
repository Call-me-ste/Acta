import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/day_header.dart';
import 'package:planner/ui/mobile/month_header.dart';
import 'package:planner/ui/mobile/week_nav_bar.dart';

/// Le tre intestazioni: **uno stile solo** per i titoli, e il comando che riporta a
/// oggi che dice dove porta.
///
/// La recensione l'aveva segnato: «i titoli delle tre viste usano tre stili di
/// testo diversi: la gerarchia tipografica non e' una sola» e «torna a oggi non
/// dice dove ti riporta». Il primo difetto e' stato chiuso quando la vista giorno
/// ha avuto la sua intestazione (tutte e tre usano `titleMedium`); questa prova lo
/// **blocca**, cosi' non torna: un token in piu' non serviva, serviva un guardiano.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Future<void> apri(WidgetTester tester) async {
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
        // Un giorno diverso da oggi: serve per avere il comando «torna a oggi».
        child: MaterialApp(
          home: CalendarPage(initialDay: DateTime(2026, 9, 14)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Lo stile del titolo di un'intestazione: e' il primo `Text` che ci mette
  /// dentro (le tre intestazioni hanno il titolo e poi le freccette, che sono
  /// icone).
  TextStyle? stileTitolo(WidgetTester tester, Type intestazione) {
    final testi = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(intestazione, skipOffstage: false),
        matching: find.byType(Text, skipOffstage: false),
      ),
    );
    return testi.first.style;
  }

  testWidgets('i tre titoli usano lo stesso stile', (tester) async {
    await apri(tester);

    final mese = stileTitolo(tester, MonthHeader);
    final settimana = stileTitolo(tester, WeekNavBar);
    final giorno = stileTitolo(tester, DayHeader);

    expect(mese, isNotNull);
    expect(
      settimana,
      mese,
      reason: 'la settimana deve usare lo stile del titolo del mese',
    );
    expect(
      giorno,
      mese,
      reason: 'il giorno deve usare lo stile del titolo del mese',
    );
  });

  testWidgets('le tre intestazioni usano le icone dei token', (tester) async {
    await apri(tester);

    for (final tipo in [MonthHeader, WeekNavBar, DayHeader]) {
      final icone = tester.widgetList<Icon>(
        find.descendant(
          of: find.byType(tipo, skipOffstage: false),
          matching: find.byType(Icon, skipOffstage: false),
        ),
      );
      for (final icona in icone) {
        expect(
          icona.size,
          icona.icon == Icons.expand_more
              ? AppSpacing.iconSmall
              : AppSpacing.icon,
          reason: 'icona fuori token in $tipo',
        );
      }
    }
  });

  testWidgets('torna a oggi dice la data verso cui riporta', (tester) async {
    await apri(tester);

    expect(find.byTooltip('Torna a oggi'), findsOneWidget);
    final oggi = DateFormat('d MMM', 'it_IT').format(DateTime.now());
    expect(
      find.text('Oggi $oggi'),
      findsOneWidget,
      reason: 'il comando deve dire dove porta, non solo mostrare un\'icona',
    );
  });
}
