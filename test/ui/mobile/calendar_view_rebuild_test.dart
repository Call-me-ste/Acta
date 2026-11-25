import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/day_view.dart';
import 'package:planner/ui/mobile/month_view.dart';
import 'package:planner/ui/mobile/week_view.dart';
import '../../support/grid.dart';

/// Il costo di un cambio vista, misurato in **istanze ricostruite** invece che in
/// millisecondi.
///
/// Perché così: un tempo preso su un emulatore non vale niente (non ha GPU, e
/// con l'host carico lo stesso codice fa 4 ms o 900 ms — misurato entrambi), e
/// nemmeno un tempo preso in debug. Quello che si può affermare è strutturale, e
/// si conta: cambiando vista, la vista che **non** si vede non si ricostruisce.
/// Flutter salta la ricostruzione di un sottoalbero quando il widget ricevuto è
/// lo **stesso oggetto** — ed è esattamente quello che fa la memoria in
/// `CalendarPage`.
void main() {
  late DatabaseService db;
  late EventProvider events;
  late TodoProvider todos;
  late AppSettingsController settings;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
    todos = TodoProvider(db);
    settings = AppSettingsController(db.settings)..load();

    await events.addEvent(
      title: 'Palestra',
      start: DateTime(2026, 9, 14, 18),
      end: DateTime(2026, 9, 14, 19),
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO',
    );
    await todos.addTodo(title: 'Spesa', dueDate: DateTime(2026, 9, 15));
  });

  tearDown(() => db.close());

  Widget harness() => MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ChangeNotifierProvider<AppSettingsController>.value(value: settings),
          ChangeNotifierProvider<PaletteController>.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
        ],
        child: MaterialApp(
          home: CalendarPage(initialDay: DateTime(2026, 9, 14)),
        ),
      );

  /// L'istanza di widget della vista: se è la stessa, Flutter non ricostruisce.
  ///
  /// `.first` e non `.single`: la `PageView` della vista giorno tiene vivi tre
  /// giorni (quello scelto e i due vicini), quindi di `DayView` ce n'è più d'uno.
  /// L'ordine dell'albero è stabile, quindi la prima è sempre la stessa pagina.
  T vista<T extends Widget>(WidgetTester tester) =>
      tester.widgetList<T>(find.byType(T, skipOffstage: false)).first;

  testWidgets('cambiando vista le altre viste restano le stesse istanze',
      (tester) async {
    await tester.pumpWidget(harness());
    // `pumpAndSettle` e non un fotogramma solo: all'apertura le viste si
    // disegnano una volta tutte insieme (riscaldamento), quindi per due
    // fotogrammi sono in scena — coperte, ma presenti nell'albero.
    await tester.pumpAndSettle();

    var mese = vista<MonthView>(tester);
    var settimana = vista<WeekView>(tester);
    var giorno = vista<DayView>(tester);

    for (final nome in ['Settimana', 'Giorno', 'Mese', 'Giorno']) {
      await tester.tap(find.text(nome));
      await tester.pumpAndSettle();

      expect(
        identical(vista<MonthView>(tester), mese),
        isTrue,
        reason: 'la griglia del mese non si ricostruisce passando a «$nome»',
      );
      expect(
        identical(vista<WeekView>(tester), settimana),
        isTrue,
        reason: 'la settimana non si ricostruisce passando a «$nome»',
      );
      expect(
        identical(vista<DayView>(tester), giorno),
        isTrue,
        reason: 'la vista giorno non si ricostruisce passando a «$nome»',
      );

      mese = vista<MonthView>(tester);
      settimana = vista<WeekView>(tester);
      giorno = vista<DayView>(tester);
    }
  });

  testWidgets('cambiando giorno si ricostruisce solo la vista che si guarda',
      (tester) async {
    await tester.pumpWidget(harness());
    // `pumpAndSettle` e non un fotogramma solo: all'apertura le viste si
    // disegnano una volta tutte insieme (riscaldamento), quindi per due
    // fotogrammi sono in scena — coperte, ma presenti nell'albero.
    await tester.pumpAndSettle();

    final settimanaNascosta = vista<WeekView>(tester);
    final meseAttivo = vista<MonthView>(tester);

    // Un giorno della griglia, restando nel mese.
    await toccaGiorno(tester, DateTime(2026, 9, 16));
    await tester.pumpAndSettle();

    expect(
      identical(vista<MonthView>(tester), meseAttivo),
      isFalse,
      reason: 'la vista che si guarda deve rifarsi: mostra il giorno scelto',
    );
    expect(
      identical(vista<WeekView>(tester), settimanaNascosta),
      isTrue,
      reason: 'la vista che non si vede non deve pagare il cambio giorno: era '
          'il fotogramma da 13 ms di lavoro Dart, misurato sul telefono',
    );

    // E appena diventa quella che si guarda si rifa': niente dati vecchi.
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();
    expect(
      identical(vista<WeekView>(tester), settimanaNascosta),
      isFalse,
      reason:
          'diventando attiva deve allinearsi al giorno scelto nel frattempo',
    );
  });
}
