import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/domain/event_occurrence.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/ui/mobile/cluster_badge.dart';
import 'package:planner/ui/mobile/cluster_sheet.dart';
import 'package:planner/ui/mobile/week_day_column.dart';

/// Il foglio del cluster: aprendo il bollino «+N» si vedono **tutti** gli
/// elementi del cluster, ciascuno con la sua fascia, e il tocco su una riga
/// passa gli stessi callback della vista.
void main() {
  late DatabaseService db;
  late AppSettingsController settings;

  final giorno = DateTime(2026, 9, 14);

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    settings = AppSettingsController(db.settings)..load();
  });

  tearDown(() => db.close());

  List<SingleChildWidget> providers() => [
        Provider<DatabaseService>.value(value: db),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(
          value: PaletteController(db)
            ..load()
            ..allineaPresets(),
        ),
      ];

  EventOccurrence occorrenza(String titolo, int inizio, int fine,
      {bool allDay = false}) {
    final start = DateTime(
      giorno.year,
      giorno.month,
      giorno.day,
      inizio ~/ 60,
      inizio % 60,
    );
    final end = DateTime(
      giorno.year,
      giorno.month,
      giorno.day,
      fine ~/ 60,
      fine % 60,
    );
    return EventOccurrence(
      event: Event(
        id: titolo,
        title: titolo,
        start: start,
        end: end,
        allDay: allDay,
      ),
      date: giorno,
      start: start,
      end: end,
    );
  }

  final serie = Todo(
    id: 'serie-4',
    title: 'Serie 4',
    dueDate: giorno,
    startMinutes: 21 * 60,
    endMinutes: 22 * 60,
  );

  /// Il cluster sta alle 18:00, quindi in fondo a 1152 px di griglia: come nel
  /// test della scheda Todo, lo schermo si allarga (800x600 non ci sta).
  Future<void> schermoAlto(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets(
      'il bollino apre il foglio col cluster intero: tre righe, ciascuna con '
      'la sua fascia', (tester) async {
    await schermoAlto(tester);
    // L'esempio del contratto: evento 18-22, evento 20-22, todo 21-22.
    var aperto = false;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers(),
        child: MaterialApp(
          locale: const Locale('it', 'IT'),
          supportedLocales: const [Locale('it', 'IT')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: WeekDayColumn(
              day: giorno,
              occurrences: [
                occorrenza('Fisica', 18 * 60, 22 * 60),
                occorrenza('Nuoto', 20 * 60, 22 * 60),
              ],
              todos: [serie],
              onTap: (_) => aperto = true,
              onOpenTodo: (todo, day) => aperto = true,
              isDone: (todo, day) => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Il cluster ha tre elementi: prima casella, poi «+1» evento e pallino
    // «+1» todo nel secondo riquadro (i due tipi si contano a parte).
    expect(find.byType(ClusterBadge), findsOneWidget);
    expect(
      find.text('+1'),
      findsNWidgets(2),
      reason: 'un evento nascosto e un todo nascosto, ognuno col suo conto',
    );
    await tester.tap(find.byType(ClusterBadge));
    await tester.pumpAndSettle();

    expect(find.byType(ClusterSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ClusterSheet),
        matching: find.text('Lunedì 14 settembre'),
      ),
      findsOneWidget,
      reason: 'il titolo del foglio è il giorno',
    );
    final righe = find.descendant(
      of: find.byType(ClusterSheet),
      matching: find.byType(InkWell),
    );
    expect(righe, findsNWidgets(3), reason: 'visibili e nascosti, tutti e tre');

    // Ogni riga dice la propria fascia, in ordine di inizio.
    for (final fascia in [
      '18:00 - 22:00',
      '20:00 - 22:00',
      '21:00 - 22:00',
    ]) {
      expect(
        find.descendant(
          of: find.byType(ClusterSheet),
          matching: find.text(fascia),
        ),
        findsOneWidget,
        reason: 'la fascia $fascia è sulle riga che le appartiene',
      );
    }
    expect(aperto, isFalse, reason: 'aprire il foglio non tocca gli elementi');

    // Fatto → titolo barrato.
    final titoloTodo = tester.widget<Text>(
      find.descendant(
        of: find.byType(ClusterSheet),
        matching: find.text('Serie 4'),
      ),
    );
    expect(titoloTodo.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('toccare una riga del foglio passa onTap e onOpenTodo',
      (tester) async {
    await schermoAlto(tester);
    final eventiToccati = <String>[];
    final todoToccati = <String>[];
    DateTime? giornoToccato;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers(),
        child: MaterialApp(
          locale: const Locale('it', 'IT'),
          supportedLocales: const [Locale('it', 'IT')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: WeekDayColumn(
              day: giorno,
              occurrences: [
                occorrenza('Fisica', 18 * 60, 22 * 60),
                occorrenza('Nuoto', 20 * 60, 22 * 60),
              ],
              todos: [serie],
              onTap: (occurrence) => eventiToccati.add(occurrence.title),
              onOpenTodo: (todo, day) {
                todoToccati.add(todo.title);
                giornoToccato = day;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ClusterBadge));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(ClusterSheet),
        matching: find.text('Fisica'),
      ),
    );
    await tester.pumpAndSettle();
    expect(eventiToccati, ['Fisica'], reason: 'onTap arriva con la riga');
    expect(find.byType(ClusterSheet), findsNothing,
        reason: 'il foglio si chiude aprendo la riga');

    await tester.tap(find.byType(ClusterBadge));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ClusterSheet),
        matching: find.text('Serie 4'),
      ),
    );
    await tester.pumpAndSettle();
    expect(todoToccati, ['Serie 4'], reason: 'onOpenTodo arriva con la riga');
    expect(giornoToccato, giorno);
  });

  testWidgets('gli all-day dicono «Tutto il giorno»', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: providers(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showClusterSheet(
                  context,
                  day: giorno,
                  eventi: [
                    occorrenza('Festa', 0, 23 * 60 + 59, allDay: true),
                  ],
                  todos: const [],
                ),
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.byType(ClusterSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ClusterSheet),
        matching: find.text('Tutto il giorno'),
      ),
      findsOneWidget,
    );
  });
}
