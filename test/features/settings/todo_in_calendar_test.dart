import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/todo_in_calendar_row.dart';

/// «Todo nel calendario»: la preferenza, i suoi tre valori, e la **riga** che li
/// sceglie (una riga sola con il valore, le tre voci nel foglio).
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  test('nasce compatta, e quello che si sceglie si ritrova', () async {
    final settings = AppSettingsController(db.settings)..load();
    expect(settings.todoInCalendario, TodoInCalendario.compatta);

    settings.setTodoInCalendario(TodoInCalendario.nascosta);

    // La scrittura su disco passa da una **microattività** (per non pagare il
    // disco dentro il fotogramma del gesto): si cede il turno prima di rileggere.
    await Future<void>.delayed(Duration.zero);

    // Un avvio nuovo, sulla stessa memoria: e' quello che succede riaprendo l'app.
    final riletto = AppSettingsController(db.settings)..load();
    expect(riletto.todoInCalendario, TodoInCalendario.nascosta);
  });

  test('un valore sconosciuto cade su compatta invece di bloccare', () {
    db.settings.set('todoInCalendario', 'boh');

    final settings = AppSettingsController(db.settings)..load();
    expect(
      settings.todoInCalendario,
      TodoInCalendario.compatta,
      reason: 'una preferenza scritta da una versione piu\' nuova non deve '
          'impedire l\'avvio',
    );
  });

  testWidgets('la riga dice il valore e il foglio offre le tre voci',
      (tester) async {
    final settings = AppSettingsController(db.settings)..load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: db),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
          ChangeNotifierProvider.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TodoInCalendarRow()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // La riga: il valore attuale, non le tre voci tutte insieme.
    expect(find.text('To do nel calendario'), findsOneWidget);
    expect(find.text('Compatta'), findsOneWidget,
        reason: 'la riga dice com\'e\' impostata senza aprire niente');
    expect(find.text('Nascosta'), findsNothing);
    expect(find.text('Pieni'), findsNothing);

    // Il foglio: le tre voci con le loro spiegazioni.
    await tester.tap(find.byKey(const ValueKey('todo-nel-calendario')));
    await tester.pumpAndSettle();
    for (final (modo, titolo, spiegazione) in TodoInCalendarRow.voci) {
      expect(
        find.byKey(ValueKey('azione-${modo.name}')),
        findsOneWidget,
        reason: 'manca la voce «$titolo»',
      );
      expect(find.text(spiegazione), findsOneWidget,
          reason: 'la spiegazione di «$titolo» serve **qui**, dove si sceglie');
    }

    await tester.tap(find.byKey(const ValueKey('azione-nascosta')));
    await tester.pumpAndSettle();

    expect(settings.todoInCalendario, TodoInCalendario.nascosta);
    expect(find.text('Nascosta'), findsOneWidget,
        reason: 'la riga si aggiorna con la scelta');
  });
}
