import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/settings/priority_colors.dart';
import 'package:planner/features/todos/todo_filter_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_selection.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/cluster_badge.dart';
import 'package:planner/ui/mobile/day_event_block.dart';
import 'package:planner/ui/mobile/day_timeline.dart';
import 'package:planner/ui/mobile/todo_compact_row.dart';
import 'package:planner/ui/shared/priority_style.dart';

/// Il cap a 2 caselle nel **giorno**: le due regioni sono già separate e
/// ognuna fa i suoi cluster — gli eventi a sinistra, i todo nella loro colonna.
/// Il bollino di todo è colorato col colore della priorità più urgente fra i
/// nascosti.
void main() {
  late DatabaseService db;
  late AppSettingsController settings;
  late TodoProvider todos;
  late EventProvider events;

  final giorno = DateTime(2026, 9, 14);

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    settings = AppSettingsController(db.settings)..load();
    todos = TodoProvider(db);
    events = EventProvider(db);
  });

  tearDown(() => db.close());

  List<SingleChildWidget> providers() => [
        Provider<DatabaseService>.value(value: db),
        ChangeNotifierProvider.value(value: events),
        ChangeNotifierProvider.value(value: todos),
        ChangeNotifierProvider(create: (_) => SelezioneDeiTodo()),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: CategoryController(db)),
        ChangeNotifierProvider.value(
          value: PaletteController(db)
            ..load()
            ..allineaPresets(),
        ),
        ChangeNotifierProvider(
          create: (_) => TodoFilterController(db.settings)..load(),
        ),
      ];

  Future<void> pumpCalendario(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: providers(),
        child: MaterialApp(home: CalendarPage(initialDay: giorno)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Il bollino **nella griglia del giorno** (la vista giorno costruisce tre
  /// giornate, ma scoppia solo quella coi dati di prova).
  Finder bollini() => find.descendant(
        of: find.byType(DayTimeline),
        matching: find.byType(ClusterBadge),
      );

  testWidgets('tre eventi sovrapposti: 2 caselle + «+1»', (tester) async {
    for (final (inizio, fine) in [
      (9 * 60, 10 * 60 + 30),
      (9 * 60 + 30, 11 * 60),
      (10 * 60, 11 * 60 + 30),
    ]) {
      await events.addEvent(
        title: 'Impegno $inizio',
        start: DateTime(
            giorno.year, giorno.month, giorno.day, inizio ~/ 60, inizio % 60),
        end: DateTime(
            giorno.year, giorno.month, giorno.day, fine ~/ 60, fine % 60),
      );
    }
    await pumpCalendario(tester);
    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    final blocchi = find.descendant(
      of: find.byType(DayTimeline),
      matching: find.byType(DayEventBlock),
    );
    expect(blocchi, findsNWidgets(2), reason: 'prime 2 caselle per inizio');
    expect(bollini(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DayTimeline),
        matching: find.text('+1'),
      ),
      findsOneWidget,
      reason: 'il terzo è nel bollino',
    );
  });

  testWidgets(
      'tre todo nella colonna: 2 righe + pallino «+1» col colore del nascosto',
      (tester) async {
    await todos.addTodo(
      title: 'Bassa',
      dueDate: giorno,
      startMinutes: 8 * 60,
      endMinutes: 9 * 60,
      priority: 0,
    );
    await todos.addTodo(
      title: 'Media',
      dueDate: giorno,
      startMinutes: 8 * 60 + 30,
      endMinutes: 9 * 60 + 30,
      priority: 1,
    );
    // Il nascosto è quello più urgente: il bollino prende il suo colore.
    await todos.addTodo(
      title: 'Urgente',
      dueDate: giorno,
      startMinutes: 8 * 60 + 45,
      endMinutes: 9 * 60 + 45,
      priority: 3,
    );
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);
    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    final righe = find.descendant(
      of: find.byType(DayTimeline),
      matching: find.byType(TodoCompactRow),
    );
    expect(righe, findsNWidgets(2), reason: 'prime 2 caselle nella colonna');
    expect(bollini(), findsOneWidget);

    // Il pallino dei todo: interno col colore del todo nascosto — qui senza
    // colore scelto, quindi in fallback vale la sua priorità (Urgente → rosso).
    final pallino = tester.widget<CircleAvatar>(
      find.descendant(of: bollini(), matching: find.byType(CircleAvatar)),
    );
    expect(
      pallino.backgroundColor,
      priorityColorFrom(defaultPriorityColors, 3),
      reason: 'todo nascosto senza colore scelto: vale la sua priorità',
    );
  });

  testWidgets(
      'il pallino conta tutti i non mostrati: interno col colore del primo',
      (tester) async {
    // Quattro todo in catena, in settimana → si vede il **primo** e il
    // secondo riquadro fa il pallino «+3» (Bassa, Alta e Media nascoste). Il
    // colore è quello del **primo nascosto** — Bassa, senza colore scelto:
    // vale la sua priorità (Bassa → azzurro), non la più alta.
    await todos.addTodo(
      title: 'Urgente visibile',
      dueDate: giorno,
      startMinutes: 8 * 60,
      endMinutes: 9 * 60,
      priority: 3,
    );
    await todos.addTodo(
      title: 'Bassa visibile',
      dueDate: giorno,
      startMinutes: 8 * 60 + 10,
      endMinutes: 9 * 60 + 10,
      priority: 0,
    );
    await todos.addTodo(
      title: 'Alta nascosta',
      dueDate: giorno,
      startMinutes: 8 * 60 + 20,
      endMinutes: 9 * 60 + 20,
      priority: 2,
    );
    await todos.addTodo(
      title: 'Media nascosta',
      dueDate: giorno,
      startMinutes: 8 * 60 + 30,
      endMinutes: 9 * 60 + 30,
      priority: 1,
    );
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    final bollino = find.byType(ClusterBadge);
    expect(bollino, findsOneWidget);
    expect(find.text('+3'), findsOneWidget,
        reason: 'tre todo nascosti, nel pallino');
    final pallino = tester.widget<CircleAvatar>(
      find.descendant(of: bollino, matching: find.byType(CircleAvatar)),
    );
    expect(pallino.backgroundColor, priorityColorFrom(defaultPriorityColors, 0),
        reason: 'il primo nascosto non ha colore scelto: la sua priorità');
  });
}
