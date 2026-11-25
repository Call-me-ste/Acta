import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/filters/filtro_condiviso.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/day_view.dart';
import 'package:planner/ui/mobile/item_form.dart';
import 'package:planner/ui/mobile/item_sheet.dart';
import 'package:planner/features/calendar/month_window.dart';
import 'package:planner/ui/mobile/month_view.dart';
import 'package:planner/ui/mobile/week_view.dart';

import '../../support/finders.dart';
import '../../support/grid.dart';

/// La scelta mese/giorno deve **sopravvivere all'app**: si verifica creando una
/// seconda istanza del controller sugli stessi dati, come farebbe un riavvio.
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
  });

  tearDown(() => db.close());

  Widget harness(DateTime day) => MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          // Istanze condivise col test (non themeProviders): la persistenza si
          // verifica sullo **stesso** oggetto che la pagina usa.
          ChangeNotifierProvider<AppSettingsController>.value(value: settings),
          ChangeNotifierProvider<PaletteController>.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
          ChangeNotifierProvider<CategoryController>.value(
            value: CategoryController(db),
          ),
        ],
        child: MaterialApp(home: CalendarPage(initialDay: day)),
      );

  Future<void> pumpPage(WidgetTester tester, DateTime day) async {
    await tester.pumpWidget(harness(day));
    await tester.pumpAndSettle();
  }

  testWidgets('la vista si sceglie dalla pillola e resta al riavvio',
      (tester) async {
    await pumpPage(tester, DateTime(2026, 9, 14));
    expect(calendarFinder, findsOneWidget);

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    expect(find.byType(DayView), findsOneWidget);
    expect(calendarFinder, findsNothing);
    expect(settings.calendarView, CalendarView.giorno);

    final reopened = AppSettingsController(db.settings)..load();
    expect(reopened.calendarView, CalendarView.giorno);
  });

  testWidgets('la vista giorno separa all-day, orari e todo', (tester) async {
    await events.addEvent(
      title: 'Vacanze',
      start: DateTime(2026, 9, 14),
      end: DateTime(2026, 9, 14, 23, 59),
      allDay: true,
    );
    await events.addEvent(
      title: 'Lezione',
      start: DateTime(2026, 9, 14, 9, 15),
      end: DateTime(2026, 9, 14, 9, 30),
    );
    await todos.addTodo(
        title: 'Pagare bolletta', dueDate: DateTime(2026, 9, 14));

    await pumpPage(tester, DateTime(2026, 9, 14));
    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    expect(find.text('Vacanze'), findsOneWidget);
    expect(find.text('Lezione'), findsOneWidget);

    // I todo del giorno stanno nella fascia **in fondo**, chiusa di default:
    // e' il "pulldown" che c'e' nel mese, ma sotto invece che sopra (richiesta
    // dell'utente). Da chiusa le righe non sono nemmeno nell'albero, quindi si
    // apre col tocco sulla barretta.
    expect(find.text('To do del giorno (1)'), findsOneWidget);
    expect(find.text('Pagare bolletta'), findsNothing);
    expect(
      tester.getTopLeft(find.text('To do del giorno (1)')).dy,
      greaterThan(tester.getTopLeft(find.text('Lezione')).dy),
      reason: 'la fascia sta sotto la giornata, non sopra',
    );

    await tester.tap(find.text('To do del giorno (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Pagare bolletta'), findsOneWidget);
  });

  testWidgets('un evento ricorrente compare solo nel suo giorno',
      (tester) async {
    // 7 settembre 2026 è lunedì: le occorrenze settimanali cadono il 14, il 21…
    // mai il 15 (il bug della v2 era comparirlo in OGNI giorno).
    await events.addEvent(
      title: 'Corso',
      start: DateTime(2026, 9, 7, 18),
      end: DateTime(2026, 9, 7, 19),
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO',
    );

    await pumpPage(tester, DateTime(2026, 9, 14));
    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();
    expect(find.text('Corso'), findsOneWidget);

    // Swipe al giorno dopo: il 15 non è nella serie.
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Corso'), findsNothing);
  });

  testWidgets('la pillola ha la vista settimana e la scelta resta al riavvio',
      (tester) async {
    await pumpPage(tester, DateTime(2026, 9, 14));

    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    expect(find.byType(WeekView), findsOneWidget);
    expect(calendarFinder, findsNothing);
    // Le intestazioni dei giorni: sigle italiane, come nel resto dell'app.
    expect(find.text('lun'), findsOneWidget);
    expect(settings.calendarView, CalendarView.settimana);

    final reopened = AppSettingsController(db.settings)..load();
    expect(reopened.calendarView, CalendarView.settimana);
  });

  testWidgets('la settimana mostra gli eventi nel loro giorno', (tester) async {
    // Superficie larga: sul telefono la colonna è ~45 dp e per progetto le
    // barre parlano solo col colore; qui la colonna è larga e il titolo si
    // può verificare dentro la barra.
    tester.view.physicalSize = const Size(4000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await events.addEvent(
      title: 'Colloquio',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    );
    await events.addEvent(
      title: 'Revisione',
      start: DateTime(2026, 9, 16, 14),
      end: DateTime(2026, 9, 16, 15),
    );
    await events.addEvent(
      title: 'Fiera',
      start: DateTime(2026, 9, 15),
      end: DateTime(2026, 9, 15, 23, 59),
      allDay: true,
    );

    await pumpPage(tester, DateTime(2026, 9, 14));
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    expect(find.text('Colloquio'), findsOneWidget);
    expect(find.text('Revisione'), findsOneWidget);
    expect(find.text('Fiera'), findsOneWidget);
  });

  testWidgets('con il testo ingrandito la settimana resta dentro i bordi',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await events.addEvent(
      title: 'Lezione',
      start: DateTime(2026, 9, 14, 9, 15),
      end: DateTime(2026, 9, 14, 9, 30),
    );
    await pumpPage(tester, DateTime(2026, 9, 14));
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('le tre viste sono pronte prima del primo cambio',
      (tester) async {
    await pumpPage(tester, DateTime(2026, 9, 14));

    // Il mese è in scena, gli altri due esistono già dietro le quinte: è quello
    // che toglie dal primo cambio la costruzione a freddo (24 ore di griglia,
    // 168 celle di settimana).
    expect(find.byType(MonthView), findsOneWidget);
    expect(find.byType(WeekView, skipOffstage: false), findsOneWidget);
    // Giorno ne costruisce **tre** — ieri, oggi e domani — perché la `PageView`
    // tiene pronti i vicini: qui si verifica che esistano, non quanti.
    expect(find.byType(DayView, skipOffstage: false), findsAtLeastNWidgets(1));
  });

  testWidgets(
      'il cambio vista scivola: due viste in scena solo mentre si muove',
      (tester) async {
    await pumpPage(tester, DateTime(2026, 9, 14));

    await tester.tap(find.text('Settimana'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    // In movimento ci sono tutte e due (una entra, una esce)…
    expect(find.byType(WeekView), findsOneWidget);
    expect(find.byType(MonthView), findsOneWidget);

    await tester.pumpAndSettle();

    // …e a movimento finito ne resta **una**: era la sovrapposizione che si
    // vedeva sul telefono.
    expect(find.byType(WeekView), findsOneWidget);
    expect(find.byType(MonthView), findsNothing);
    expect(find.byType(MonthView, skipOffstage: false), findsOneWidget);
  });

  testWidgets('con le animazioni spente il cambio è istantaneo',
      (tester) async {
    await pumpPage(tester, DateTime(2026, 9, 14));

    // Spente dalle preferenze: la vista nuova c'è subito e non c'è nessun
    // movimento da aspettare (durata zero, non «più veloce»).
    settings.setAnimationsEnabled(false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giorno'));
    await tester.pump();

    expect(find.byType(DayView), findsAtLeastNWidgets(1));
    expect(find.byType(MonthView), findsNothing);
  });

  testWidgets('la posizione del mese si ritrova tornando indietro',
      (tester) async {
    await pumpPage(tester, DateTime(2026, 9, 14));

    // Si tira il mese in su, come farebbe un dito.
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    final scroll = find
        .descendant(
            of: find.byType(MonthView), matching: find.byType(Scrollable))
        .first;
    final prima = tester.state<ScrollableState>(scroll).position.pixels;
    expect(prima, greaterThan(0));

    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mese'));
    await tester.pumpAndSettle();

    // Il mese non è stato distrutto: la posizione è quella di prima, non zero.
    final dopo = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(MonthView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    expect(dopo, prima);
  });

  testWidgets('con il testo ingrandito la giornata resta dentro i bordi',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await events.addEvent(
      title: 'Lezione',
      start: DateTime(2026, 9, 14, 9, 15),
      end: DateTime(2026, 9, 14, 9, 30),
    );
    await pumpPage(tester, DateTime(2026, 9, 14));
    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Lezione'), findsOneWidget);
  });

  testWidgets('un evento senza orario si salva come all-day', (tester) async {
    // Tela alta come nei golden del form: il foglio è lungo (orari, colore,
    // ricorrenza, promemoria, luogo, note, azioni) e in 800x600 i pulsanti
    // finiscono sotto il bordo — un tocco fuori schermo non arriva.
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<AppSettingsController>.value(value: settings),
          ChangeNotifierProvider<PaletteController>.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
          ChangeNotifierProvider<CategoryController>.value(
            value: CategoryController(db),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ItemForm(type: ItemType.evento, day: DateTime(2026, 9, 14)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tutto il giorno'));
    await tester.pumpAndSettle();
    // Senza orario i due campi orario non dicono niente: spariscono.
    expect(find.text('Inizio'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Titolo'), 'Vacanze');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    final day = events.occurrencesForDate(DateTime(2026, 9, 14));
    expect(day, hasLength(1));
    expect(day.single.event.allDay, isTrue);
    expect(day.single.start.hour, 0);
  });

  testWidgets('i giorni del mese contano i todo e rispettano la finestra',
      (tester) async {
    // Due todo il 5, uno il 30: i badge numerici li contano. La finestra è la
    // GRIGLIA visibile (anche i giorni di ottobre che si vedono), non il mese:
    // il 2 ottobre si vede, il 12 no.
    //
    // Il conto si guarda **nei dati** e non nei widget: i numeri dei giorni e i
    // badge li disegna il painter, quindi non c'e' piu' una chiave da cercare.
    // Che poi quei numeri finiscano sullo schermo lo dice il golden del
    // calendario, che e' li' per questo.
    await todos.addTodo(title: 'T1', dueDate: DateTime(2026, 9, 5));
    await todos.addTodo(title: 'T2', dueDate: DateTime(2026, 9, 5));
    await todos.addTodo(title: 'T3', dueDate: DateTime(2026, 9, 30));
    await todos.addTodo(title: 'Bordo', dueDate: DateTime(2026, 10, 2));
    await todos.addTodo(title: 'Fuori', dueDate: DateTime(2026, 10, 12));

    await pumpPage(tester, DateTime(2026, 9, 14));

    final conti = MonthWindow.of(
      events: events,
      todos: todos,
      focusedDay: DateTime(2026, 9, 14),
      selectedDay: DateTime(2026, 9, 14),
      filtro: const FiltroCondiviso(),
    ).todoCounts;

    expect(conti[DateTime(2026, 9, 5)], 2);
    expect(conti[DateTime(2026, 9, 30)], 1);
    expect(conti[DateTime(2026, 10, 2)], 1);
    expect(conti[DateTime(2026, 10, 12)], isNull);
  });

  testWidgets('un todo ricorrente conta una volta per giorno', (tester) async {
    await todos.addTodo(
      title: 'Ricorrente',
      dueDate: DateTime(2026, 9, 1),
      recurrenceRule: 'FREQ=DAILY',
    );

    await pumpPage(tester, DateTime(2026, 9, 14));

    final conti = MonthWindow.of(
      events: events,
      todos: todos,
      focusedDay: DateTime(2026, 9, 14),
      selectedDay: DateTime(2026, 9, 14),
      filtro: const FiltroCondiviso(),
    ).todoCounts;
    // Una occorrenza al giorno, non un accumulo dal primo della serie.
    expect(conti[DateTime(2026, 9, 14)], 1);
    expect(conti[DateTime(2026, 9, 15)], 1);
  });

  testWidgets('la sezione todo si apre e resta aperta cambiando giorno',
      (tester) async {
    await todos.addTodo(title: 'Spesa', dueDate: DateTime(2026, 9, 5));
    await todos.addTodo(title: 'Farmacia', dueDate: DateTime(2026, 9, 6));

    await pumpPage(tester, DateTime(2026, 9, 5));

    // Chiusa di default: il titolo del todo non si vede.
    expect(find.text('Spesa'), findsNothing);
    expect(find.text('To do del giorno (1)'), findsOneWidget);

    await tester.tap(find.text('To do del giorno (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Spesa'), findsOneWidget);

    // Cambio giorno: lo stato aperto si conserva, il contenuto segue il giorno.
    await toccaGiorno(tester, DateTime(2026, 9, 6));
    await tester.pumpAndSettle();
    expect(find.text('To do del giorno (1)'), findsOneWidget);
    expect(find.text('Farmacia'), findsOneWidget);
    expect(find.text('Spesa'), findsNothing);
  });
}
