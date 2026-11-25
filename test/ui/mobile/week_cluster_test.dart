import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_filter_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_selection.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/cluster_badge.dart';
import 'package:planner/ui/mobile/day_timeline.dart';
import 'package:planner/ui/mobile/week_event_block.dart';
import 'package:planner/ui/mobile/week_timeline.dart';
import 'package:planner/theme/color_resolver.dart';

/// Il cap a 2 nella **settimana**: due riquadri al massimo per cluster (tre
/// affiancati non si leggono). Con due o meno elementi le loro caselle; con
/// più di due, la prima casella + il bollino «+N» nel **secondo riquadro** —
/// largo metà colonna come le caselle, ancorato alla finestra del cluster.
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

  testWidgets(
      'quattro eventi sovrapposti: prima casella + «+3» nel secondo riquadro, '
      'mai tre riquadri', (tester) async {
    // Tutti e quattro si incrociano a catena: un solo cluster da quattro.
    for (final (inizio, fine) in [
      (10 * 60, 11 * 60 + 30),
      (10 * 60 + 15, 11 * 60),
      (10 * 60 + 30, 12 * 60),
      (10 * 60 + 45, 11 * 60 + 15),
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
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    // Con più di due si vede il primo elemento, e il secondo riquadro è il
    // bollino: il conto dice quanti stanno oltre il primo (4 → «+3»).
    final blocchi = [
      for (final blocco
          in tester.widgetList<WeekEventBlock>(find.byType(WeekEventBlock)))
        tester.getRect(find.byWidget(blocco)),
    ];
    expect(blocchi, hasLength(1), reason: 'il primo elemento resta casella');
    expect(find.text('+3'), findsOneWidget,
        reason: 'gli altri tre sono nel «+N»');

    final bollino = find.byType(ClusterBadge);
    expect(bollino, findsOneWidget, reason: 'un solo cluster scoppia');
    final rettangoloBollino = tester.getRect(bollino);
    final casella = blocchi.single;

    // I riquadri sono **due larghi metà colonna** ciascuno: la casella nella
    // prima corsia, il bollino nella seconda, stessa grafica.
    final colonna = tester.getSize(find.byType(WeekTimeline)).width / 7;
    expect(casella.width, closeTo(colonna / 2 - 2, 0.01),
        reason: 'mai tre riquadri: la casella è larga metà colonna');
    expect(rettangoloBollino.width, closeTo(colonna / 2 - 2, 0.01),
        reason: 'il bollino è un riquadro quanto una casella');
    expect(rettangoloBollino.left - casella.left, closeTo(colonna / 2, 0.01),
        reason: 'il «+N» sta nella seconda corsia, accanto alla casella');

    // Il riquadro-bollino copre la finestra del cluster (10:00 -> 12:00).
    const altezzaOra = DayTimeline.defaultHourHeight;
    final alto = tester.getTopLeft(find.byType(WeekTimeline)).dy;
    expect(rettangoloBollino.top - alto, closeTo(10 * altezzaOra, 0.01));
    expect(rettangoloBollino.height, closeTo(2 * altezzaOra, 0.01));
  });

  testWidgets('un cluster da due non ha bollino', (tester) async {
    await events.addEvent(
      title: 'Lezione',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    );
    await events.addEvent(
      title: 'Tutoraggio',
      start: DateTime(2026, 9, 14, 9, 30),
      end: DateTime(2026, 9, 14, 10, 30),
    );
    await pumpCalendario(tester);
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    expect(find.byType(WeekEventBlock), findsNWidgets(2));
    expect(find.byType(ClusterBadge), findsNothing);
  });

  testWidgets(
      'nascosti misti: riquadro colorato col evento e pallino col colore del '
      'todo', (tester) async {
    // Comincia con un evento (visibile); poi due todo e un evento, nascosti tutti.
    await events.addEvent(
      title: 'Visibile',
      start: DateTime(2026, 9, 14, 10),
      end: DateTime(2026, 9, 14, 13),
    );
    await todos.addTodo(
      title: 'Con colore',
      dueDate: giorno,
      startMinutes: 10 * 60 + 10,
      endMinutes: 11 * 60,
      colorIndex: 2,
    );
    await todos.addTodo(
      title: 'Senza colore',
      dueDate: giorno,
      startMinutes: 10 * 60 + 20,
      endMinutes: 11 * 60,
    );
    await events.addEvent(
      title: 'Evento nascosto',
      start: DateTime(2026, 9, 14, 10, 30),
      end: DateTime(2026, 9, 14, 12),
    );
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    final bollino = find.byType(ClusterBadge);
    expect(bollino, findsOneWidget);
    // I due conti, separati per tipo.
    expect(
      find.descendant(of: bollino, matching: find.text('+1')),
      findsOneWidget,
      reason: 'un evento nascosto',
    );
    expect(
      find.descendant(of: bollino, matching: find.text('+2')),
      findsOneWidget,
      reason: 'due todo nascosti, dentro il pallino',
    );

    final ctx = tester.element(bollino);
    // I colori attesi si calcolano con `read`: le `watch` di `occurrenceColor`
    // e `todoColor` girano solo **durante il build**, e da un test esplodono
    // con «listen from outside of the widget tree» (visto e corretto).
    final impostazioni = ctx.read<AppSettingsController>();
    final palette =
        ctx.read<PaletteController>().resolve(impostazioni.activePaletteId);
    final luminosita = Theme.of(ctx).brightness;
    final eventoNascosto = [
      for (final occ in events.occurrencesForDate(giorno))
        if (occ.title == 'Evento nascosto') occ,
    ].single;
    // Il riquadro è il Container **esterno** (`.first`: il pallino ne ha dei
    // suoi interni, e `widget<>` esploderebbe con «Too many elements»).
    final riquadro = tester
        .widgetList<Container>(
          find.descendant(of: bollino, matching: find.byType(Container)),
        )
        .first;
    expect(
      (riquadro.decoration! as BoxDecoration).color,
      ColorResolver.elementColor(
        palette: palette,
        brightness: luminosita,
        index: eventoNascosto.colorIndex,
        customHex: eventoNascosto.event.colorHex,
      ).withValues(alpha: 0.32),
      reason: 'il riquadro prende il colore dell\'evento nascosto',
    );
    // …e il pallino ha l'interno del colore scelto del primo todo nascosto.
    final pallino = tester.widget<CircleAvatar>(
      find.descendant(of: bollino, matching: find.byType(CircleAvatar)),
    );
    expect(
      pallino.backgroundColor,
      ColorResolver.elementColor(
        palette: palette,
        brightness: luminosita,
        index: 2,
      ),
      reason: 'il colore del todo, non la priorità',
    );
  });

  testWidgets('un cluster da solo non è stretto da un «+N» nello stesso giorno',
      (tester) async {
    // Un evento da solo alle 8 e, più tardi, un cluster con il bollino: la
    // larghezza è **del cluster**, e quello da solo tiene tutta la colonna
    // (era il bug: la corsia del giorno lo stringeva a metà).
    await events.addEvent(
      title: 'Solo',
      start: DateTime(2026, 9, 14, 8),
      end: DateTime(2026, 9, 14, 9),
    );
    for (final (inizio, fine) in [
      (10 * 60, 11 * 60),
      (10 * 60 + 15, 11 * 60 + 15),
      (10 * 60 + 30, 12 * 60),
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
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    final colonna = tester.getSize(find.byType(WeekTimeline)).width / 7;
    final solo = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is WeekEventBlock && widget.occurrence.title == 'Solo',
      ),
    );
    expect(
      solo.width,
      closeTo(colonna - 2, 0.01),
      reason:
          'da solo occupa tutta la colonna, come gli eventi degli altri giorni',
    );
    // Il cluster vicino resta a due riquadri: metà colonna ciascuno.
    final bollino = tester.getRect(find.byType(ClusterBadge));
    expect(bollino.width, closeTo(colonna / 2 - 2, 0.01),
        reason: 'il bollino è il secondo riquadro del suo cluster');
  });
}
