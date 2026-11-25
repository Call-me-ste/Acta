import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/domain/event_occurrence.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/theme/color_resolver.dart';
import 'package:planner/ui/mobile/agenda_day_group.dart';
import 'package:planner/ui/mobile/agenda_event_box.dart';

import '../../support/theme_providers.dart';

/// Il gruppo del giorno e il box dell'evento, da soli: il colore del box, dove
/// stanno titolo e orario, e l'ordine dentro il gruppo.
void main() {
  late DatabaseService db;

  final giorno = DateTime(2026, 9, 14, 9);

  EventOccurrence occorrenza({
    required String titolo,
    int ora = 9,
    int colorIndex = 0,
    bool allDay = false,
  }) {
    final start = DateTime(2026, 9, 14, ora);
    final end =
        allDay ? DateTime(2026, 9, 15) : start.add(const Duration(hours: 2));
    return EventOccurrence(
      event: Event(
        id: 'e-$titolo',
        title: titolo,
        start: start,
        end: end,
        allDay: allDay,
        colorIndex: colorIndex,
      ),
      date: DateTime(2026, 9, 14),
      start: start,
      end: end,
    );
  }

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Future<void> apri(
    WidgetTester tester, {
    List<EventOccurrence> allDay = const [],
    List<EventOccurrence> timed = const [],
    List<Todo> todos = const [],
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...themeProviders(db),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider(create: (_) => TodoProvider(db)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AgendaDayGroup(
              day: giorno,
              allDay: allDay,
              timed: timed,
              todos: todos,
              oggi: giorno,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('il box è pieno col colore dell\'evento', (tester) async {
    await apri(tester, timed: [occorrenza(titolo: 'Lezione', colorIndex: 3)]);

    final scatola = tester.widget<Material>(
      find.descendant(
        of: find.byType(AgendaEventBox),
        matching: find.byType(Material),
      ),
    );

    // Il colore atteso si calcola con la stessa regola dell'app (l'indice nella
    // palette attiva, tema chiaro): non si guarda a occhio e non si copia.
    final palette = PaletteController(db)
      ..load()
      ..allineaPresets();
    final impostazioni = AppSettingsController(db.settings)..load();
    final atteso = ColorResolver.elementColor(
      palette: palette.resolve(impostazioni.activePaletteId),
      brightness: Brightness.light,
      index: 3,
    );

    expect(scatola.color, atteso);
  });

  testWidgets('titolo a sinistra, orario a destra', (tester) async {
    await apri(tester, timed: [occorrenza(titolo: 'Lezione')]);
    await tester.binding.setSurfaceSize(null);

    final titolo = tester.getRect(find.text('Lezione'));
    final orario = tester.getRect(find.text('09:00 - 11:00'));

    expect(titolo.left, lessThan(orario.left));
    expect(titolo.right, lessThanOrEqualTo(orario.left));
    // Sulla stessa riga, non uno sotto l'altro.
    expect(titolo.center.dy, closeTo(orario.center.dy, 1));
  });

  testWidgets('i tutto-il-giorno stanno in cima, e senza orario',
      (tester) async {
    await apri(
      tester,
      allDay: [occorrenza(titolo: 'Compleanno', allDay: true, colorIndex: 5)],
      timed: [occorrenza(titolo: 'Lezione')],
    );

    final compleanno = tester.getRect(find.text('Compleanno'));
    final lezione = tester.getRect(find.text('Lezione'));

    expect(compleanno.top, lessThan(lezione.top), reason: 'prima lui');
    // Un evento di giornata intera non ha un orario da dire: le 00:00 e le 23:59
    // sono gli orari veri dell'evento, non qualcosa da mostrare.
    expect(find.textContaining('00:00'), findsNothing);
  });

  testWidgets('l\'intestazione dice il giorno e la linea scende per il gruppo',
      (tester) async {
    await apri(
      tester,
      allDay: const [],
      timed: [occorrenza(titolo: 'Lezione')],
      todos: [Todo(id: 't1', title: 'Bolletta', dueDate: giorno)],
    );

    expect(find.text('14'), findsOneWidget);
    expect(find.text('lun'), findsOneWidget);

    // L'intestazione copre il tratto iniziale della linea senza misurare
    // due volte le righe del gruppo.
    final linea = find.byWidgetPredicate(
      (widget) => widget is Container && widget.constraints?.maxWidth == 2,
    );
    final rettangolo = tester.getRect(linea);
    final header = find.byKey(const ValueKey('agenda-day-header'));
    final areaHeader = tester.getRect(header);

    expect(tester.widget<ColoredBox>(header).color.a, 1);
    expect(areaHeader.contains(rettangolo.topCenter), isTrue);
    expect(
      areaHeader.bottom,
      greaterThanOrEqualTo(tester.getRect(find.text('lun')).bottom),
    );
    expect(rettangolo.bottom - areaHeader.bottom, greaterThan(8));
    // Scende **fino in fondo al gruppo**: è quello che tiene insieme
    // l'intestazione e le righe.
    expect(
      rettangolo.bottom,
      closeTo(tester.getRect(find.byType(AgendaDayGroup)).bottom, 1),
    );
  });
}
