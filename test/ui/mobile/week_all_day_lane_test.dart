import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/domain/event_occurrence.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/settings/priority_colors.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/ui/mobile/cluster_badge.dart';
import 'package:planner/ui/mobile/cluster_sheet.dart';
import 'package:planner/ui/mobile/week_all_day_lane.dart';
import 'package:planner/ui/shared/priority_style.dart';

/// La fascia all-day: il «+N» di testo diventa il **bollino tappabile**, con lo
/// stile e la regola di colore delle griglie — e aprendo mostra tutti gli
/// elementi del giorno (il loro cluster è l'intera cella).
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

  EventOccurrence allDay(String titolo) {
    final start = DateTime(giorno.year, giorno.month, giorno.day);
    final end = DateTime(giorno.year, giorno.month, giorno.day, 23, 59);
    return EventOccurrence(
      event: Event(
        id: titolo,
        title: titolo,
        start: start,
        end: end,
        allDay: true,
      ),
      date: giorno,
      start: start,
      end: end,
    );
  }

  Future<void> pumpLane(
    WidgetTester tester, {
    List<EventOccurrence> eventi = const [],
    List<Todo> todos = const [],
    void Function(Todo todo, DateTime day)? onTodo,
    ValueChanged<EventOccurrence>? onTap,
    bool Function(Todo todo, DateTime day)? isDone,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: providers(),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: WeekAllDayLane(
                days: [giorno],
                width: 300,
                byDay: {giorno: eventi},
                todoByDay: {giorno: todos},
                onTap: onTap,
                onTodo: onTodo,
                isDone: isDone,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tre all-day: 2 chip + «+1», tocco → foglio con tutti e tre',
      (tester) async {
    await pumpLane(
      tester,
      eventi: [allDay('Festa'), allDay('Viaggio'), allDay('Convegno')],
    );

    expect(find.text('Festa'), findsOneWidget);
    expect(find.text('Viaggio'), findsOneWidget);
    expect(find.text('Convegno'), findsNothing, reason: 'nascosto nel bollino');

    final bollino = find.byType(ClusterBadge);
    expect(bollino, findsOneWidget);
    expect(find.text('+1'), findsOneWidget);

    await tester.tap(bollino);
    await tester.pumpAndSettle();

    expect(find.byType(ClusterSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ClusterSheet),
        matching: find.text('Convegno'),
      ),
      findsOneWidget,
      reason: 'il nascosto sta nel foglio, con gli altri',
    );
    expect(
      find.descendant(
        of: find.byType(ClusterSheet),
        matching: find.text('Tutto il giorno'),
      ),
      findsNWidgets(3),
      reason: 'ogni riga dice la sua fascia',
    );
  });

  testWidgets('nascosti solo todo: il bollino è il colore della priorità',
      (tester) async {
    Todo todo(String id, int prio) => Todo(
          id: id,
          title: id,
          dueDate: giorno,
          priority: prio,
        );
    final toccati = <String>[];
    await pumpLane(
      tester,
      todos: [
        todo('Uno', 0),
        todo('Due', 1),
        todo('Tre', 3),
      ],
      onTodo: (t, day) => toccati.add(t.id),
      isDone: (t, day) => false,
    );

    expect(find.text('Uno'), findsOneWidget);
    expect(find.text('Due'), findsOneWidget);
    expect(find.text('Tre'), findsNothing);
    expect(find.text('+1'), findsOneWidget);

    // Il pallino dei todo nascosti: interno col colore del todo — «Tre» non ha
    // colore scelto, quindi in fallback vale la sua priorità (Urgente → rosso).
    final pallino = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byType(ClusterBadge),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(
      pallino.backgroundColor,
      priorityColorFrom(defaultPriorityColors, 3),
      reason: 'il primo nascosto è «Tre», senza colore scelto',
    );

    // Il tocco sul bollino apre il foglio e la riga passa onOpenTodo (che qui
    // è il `onTodo` della fascia: apre il form del todo).
    await tester.tap(find.byType(ClusterBadge));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ClusterSheet),
        matching: find.text('Tre'),
      ),
    );
    await tester.pumpAndSettle();
    expect(toccati, ['Tre']);
  });

  testWidgets('due elementi e basta: nessun bollino', (tester) async {
    await pumpLane(
      tester,
      eventi: [allDay('Festa')],
      todos: [
        Todo(id: 'solo', title: 'Senza orario', dueDate: giorno),
      ],
    );

    expect(find.text('Festa'), findsOneWidget);
    expect(find.text('Senza orario'), findsOneWidget);
    expect(find.byType(ClusterBadge), findsNothing);
  });
}
