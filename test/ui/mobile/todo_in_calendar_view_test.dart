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
import 'package:planner/features/todos/todo_recurrence.dart';
import 'package:planner/features/todos/todo_selection.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/cluster_badge.dart';
import 'package:planner/ui/mobile/day_todo_section.dart';
import 'package:planner/ui/mobile/day_timeline.dart';
import 'package:planner/ui/mobile/month_grid_painter.dart';
import 'package:planner/ui/mobile/todo_compact_row.dart';
import 'package:planner/ui/mobile/todo_page.dart';
import 'package:planner/ui/mobile/week_event_block.dart';
import 'package:planner/ui/mobile/week_timeline.dart';
import 'package:planner/ui/shared/priority_style.dart';
import 'package:planner/ui/shared/todo_check.dart';

/// «Todo nel calendario» **dove conta**: con «nascosta» il calendario non disegna
/// né pallini nel mese né fascia in fondo, e la scheda Todo resta intera.
///
/// Il giro completo (compatta -> nascosta -> compatta) non è pignoleria: la
/// seconda volta i pallini devono **riapparire**, e succede solo se la modalità
/// entra nella firma delle celle. Senza, la memoria restituirebbe le celle di
/// prima e la griglia resterebbe vuota per sempre.
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
        // La selezione multipla: da #90 la scheda Todo la legge (e il guscio la
        // usa per il tasto indietro).
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

  Future<void> pumpCalendario(WidgetTester tester, {DateTime? day}) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: providers(),
        child: MaterialApp(home: CalendarPage(initialDay: day ?? giorno)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// I pallini dei todo **disegnati**: si leggono dal painter, perché nella
  /// griglia non sono widget (è un disegno solo) e cercarli con `find` non
  /// troverebbe niente.

  /// La casella del todo **dentro la griglia delle ore**: la riga dei todo senza
  /// orario sta fuori (sotto l'intestazione) e non è questa.
  Finder casellaNellaGriglia() => find.descendant(
        of: find.byType(DayTimeline),
        matching: find.byType(TodoCompactRow),
      );

  /// Come sopra, per la settimana: la colonna del giorno.
  Finder casellaInSettimana() => find.descendant(
        of: find.byType(WeekTimeline),
        matching: find.byType(TodoCompactRow),
      );
  int pallini(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<GrigliaDelMese>()
      .expand((pennello) => pennello.giorni)
      .where((giorno) => giorno.badge != null)
      .length;

  testWidgets('compatta mostra i pallini e la fascia; nascosta no',
      (tester) async {
    await todos.addTodo(title: 'Bolletta', dueDate: giorno);
    await pumpCalendario(tester);

    expect(pallini(tester), greaterThan(0));
    expect(find.byType(DayTodoSection), findsOneWidget);

    settings.setTodoInCalendario(TodoInCalendario.nascosta);
    await tester.pumpAndSettle();

    expect(pallini(tester), 0);
    expect(find.byType(DayTodoSection), findsNothing);

    // E tornando indietro i pallini riappaiono: è la prova che la modalità entra
    // nella firma delle celle.
    settings.setTodoInCalendario(TodoInCalendario.compatta);
    await tester.pumpAndSettle();

    expect(pallini(tester), greaterThan(0));
    expect(find.byType(DayTodoSection), findsOneWidget);
  });

  testWidgets('in «pieni» il Mese non ha la fascia, ma i pallini restano',
      (tester) async {
    await todos.addTodo(title: 'Bolletta', dueDate: giorno);
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    // I todo stanno nella giornata: nel mese restano solo i pallini, senza la
    // fascia in fondo.
    expect(find.byType(DayTodoSection), findsNothing);
    expect(pallini(tester), greaterThan(0));
  });

  testWidgets(
      'in «pieni» il todo con orario entra nella timeline, alla sua ora',
      (tester) async {
    await todos.addTodo(
      title: 'Con orario',
      dueDate: giorno,
      startMinutes: 8 * 60,
    );
    await todos.addTodo(title: 'Senza orario', dueDate: giorno);
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    // Uno nella griglia, nella sua ora. La quota si legge dalla **geometria**
    // (8 * hourHeight dentro la timeline) e non dalle etichette: da quando la
    // griglia e' un disegno solo, le etichette non sono piu' widget e `find` non
    // le troverebbe.
    expect(casellaNellaGriglia(), findsOneWidget);
    final yGriglia = tester.getTopLeft(find.byType(DayTimeline)).dy;
    final yTodo = tester.getTopLeft(casellaNellaGriglia()).dy;
    expect(
      yTodo - yGriglia,
      closeTo(8 * DayTimeline.defaultHourHeight, 1),
      reason: 'la casella sta nella fascia delle 8',
    );

    // …e quello senza orario **non** sta nella griglia: e' nella riga in fondo
    // alla giornata, che si costruisce scorrendo (lo verifica il test dopo).
    expect(
      find.descendant(
        of: find.byType(DayTimeline),
        matching: find.text('Senza orario'),
      ),
      findsNothing,
    );
  });

  testWidgets('in «pieni» i todo senza orario si vedono senza scorrere',
      (tester) async {
    await todos.addTodo(title: 'Senza orario', dueDate: giorno);
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    // Si vede appena si apre il giorno. Prima stava **dentro lo scorrimento,
    // dopo le 24 ore**: c'era, ma sotto la piega, e per trovarlo bisognava
    // scorrere fino a dopo le 23 (segnalato: «in Pieni non si vedono le todo»).
    expect(find.text('Senza orario'), findsOneWidget);

    // E sta **fuori** dallo scorrimento delle ore: trascinare la griglia non lo
    // muove.
    final prima = tester.getTopLeft(find.text('Senza orario')).dy;
    await tester.drag(find.byType(DayTimeline), const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Senza orario')).dy,
      prima,
      reason: 'la riga dei todo senza orario non scorre con le ore',
    );
  });

  testWidgets('in «pieni» i todo stanno dentro la giornata, senza fascia',
      (tester) async {
    await todos.addTodo(
      title: 'Bolletta',
      dueDate: giorno,
      startMinutes: 8 * 60,
    );
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    // La riga del todo dentro la giornata, **la stessa** della striscia: nella
    // colonna stretta della griglia l'orario non ci sta e non si scrive (l'ora la
    // dice gia' la posizione della casella), il titolo si'.
    expect(casellaNellaGriglia(), findsOneWidget);
    expect(find.text('Bolletta'), findsOneWidget);
    // E la fascia in fondo non c'e': sarebbero gli stessi todo in due posti.
    expect(find.byType(DayTodoSection), findsNothing);
  });

  testWidgets('in «compatta» la giornata non ha righe, e la fascia c\'e\'',
      (tester) async {
    await todos.addTodo(
      title: 'Bolletta',
      dueDate: giorno,
      startMinutes: 8 * 60,
    );
    await pumpCalendario(tester);

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    // La fascia c'e' (chiusa: il titolo del todo non e' nell'albero), e dentro
    // la giornata non c'e' nessuna riga di todo.
    expect(find.byType(DayTodoSection), findsOneWidget);
    expect(find.text('Bolletta'), findsNothing);
  });

  testWidgets('una todo fatta resta nella striscia del mese, barrata',
      (tester) async {
    await todos.addTodo(title: 'Bolletta', dueDate: giorno);
    await todos.toggleTodo(todos.todos.single.id);
    await pumpCalendario(tester);

    // La striscia è chiusa di default: si apre col tocco sull'intestazione.
    await tester.tap(find.textContaining('To do del giorno'));
    await tester.pumpAndSettle();

    // Resta **visibile**, e si vede che è fatta: cerchio pieno e titolo barrato.
    expect(find.text('Bolletta'), findsOneWidget);
    expect(tester.widget<TodoCheck>(find.byType(TodoCheck)).done, isTrue);
    expect(
      tester.widget<Text>(find.text('Bolletta')).style?.decoration,
      TextDecoration.lineThrough,
    );
  });

  testWidgets('scorrere a destra la toglie dal calendario, l\'annulla rimette',
      (tester) async {
    await todos.addTodo(title: 'Bolletta', dueDate: giorno);
    await pumpCalendario(tester);
    await tester.tap(find.textContaining('To do del giorno'));
    await tester.pumpAndSettle();
    expect(find.text('Bolletta'), findsOneWidget);

    await tester.drag(find.text('Bolletta'), const Offset(600, 0));
    await tester.pumpAndSettle();

    // Fuori dal calendario: il segno è scritto **sul todo** (quindi viaggia).
    expect(find.text('Bolletta'), findsNothing);
    expect(todos.todos.single.hiddenInCalendar, isTrue);

    // E l'avviso con «Annulla» la rimette, senza perdere niente.
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(todos.todos.single.hiddenInCalendar, isFalse);

    // La fascia era sparita con l'ultimo todo (e con lei lo stato aperto/chiuso:
    // ponytail, vedi `day_todo_section.dart`): torna chiusa, si riapre e il todo
    // e' li', con la sua spunta.
    await tester.tap(find.textContaining('To do del giorno'));
    await tester.pumpAndSettle();
    expect(find.text('Bolletta'), findsOneWidget);
  });

  testWidgets('in «pieni» la casella fatta resta nella griglia, sbiadita',
      (tester) async {
    await todos.addTodo(
      title: 'Con orario',
      dueDate: giorno,
      startMinutes: 8 * 60,
    );
    await todos.toggleTodo(todos.todos.single.id);
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    expect(casellaNellaGriglia(), findsOneWidget);
    expect(
      tester.widget<TodoCompactRow>(casellaNellaGriglia()).done,
      isTrue,
      reason: 'la casella c\'è ancora, e dice che è fatta',
    );
  });

  testWidgets('in «pieni» la casella del todo è alta come quella dell\'evento',
      (tester) async {
    // Un evento di un'ora e un todo di un'ora, alla stessa ora della mattina.
    await events.addEvent(
      title: 'Lezione',
      start: DateTime(2026, 9, 14, 8),
      end: DateTime(2026, 9, 14, 9),
    );
    await todos.addTodo(
      title: 'Studiare',
      dueDate: giorno,
      startMinutes: 8 * 60,
      endMinutes: 9 * 60,
    );
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    // Stessa altezza di un evento **di un'ora**: la casella grande, non la riga
    // sottile. Il blocco dell'evento si prende dall'antenato Material più vicino
    // al suo titolo: `_EventBlock` è privato e da qui non si nomina.
    final bloccoEvento = find
        .ancestor(of: find.text('Lezione'), matching: find.byType(Material))
        .first;
    expect(
      tester.getSize(casellaNellaGriglia()).height,
      closeTo(tester.getSize(bloccoEvento).height, 1),
      reason: 'un todo di un\'ora occupa la casella di un evento di un\'ora',
    );
  });

  testWidgets('un todo senza orario di fine vale un\'ora di casella',
      (tester) async {
    await todos.addTodo(
      title: 'Studiare',
      dueDate: giorno,
      startMinutes: 8 * 60,
    );
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    // «dalle 8» senza fine: la casella e' quella di un'ora. Scritta come numero,
    // cosi' una casella che si restringe a una riga sottile non passa.
    expect(
      tester.getSize(casellaNellaGriglia()).height,
      closeTo(
        DayTimeline.defaultHourHeight,
        3,
      ),
    );
  });

  testWidgets('in settimana «compatta»: la fascia del giorno scelto',
      (tester) async {
    await todos.addTodo(title: 'Bolletta', dueDate: giorno);
    await pumpCalendario(tester);

    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    // La fascia c'è (chiusa: il titolo non è nell'albero) e si apre col tocco,
    // come nel mese e nel giorno: e' lo stesso `DayTodoSection`.
    expect(find.byType(DayTodoSection), findsOneWidget);
    expect(find.text('Bolletta'), findsNothing);
    await tester.tap(find.textContaining('To do del giorno'));
    await tester.pumpAndSettle();
    expect(find.text('Bolletta'), findsOneWidget);
  });

  testWidgets(
      'in settimana la fascia c\'è anche col giorno scelto che ha un orario',
      (tester) async {
    await todos.addTodo(title: 'Bolletta', dueDate: giorno);
    // All'avvio il giorno scelto è `DateTime.now()`, quindi **con l'orario**. Le
    // chiavi dei todo per giorno sono date: senza il taglio, la fascia non
    // comparve sul telefono e i test (che partivano da una mezzanotte) non lo
    // vedevano.
    await pumpCalendario(tester, day: DateTime(2026, 9, 14, 15, 30));

    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    expect(find.byType(DayTodoSection), findsOneWidget);
  });

  testWidgets(
      'in settimana «pieni»: il todo con orario sta nella colonna, quello '
      'senza sta nella fascia sopra la griglia', (tester) async {
    await todos.addTodo(
      title: 'Con orario',
      dueDate: giorno,
      startMinutes: 8 * 60,
      endMinutes: 9 * 60,
    );
    await todos.addTodo(title: 'Senza orario', dueDate: giorno);
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    // Niente fascia in fondo: in «pieni» i todo stanno nella giornata.
    expect(find.byType(DayTodoSection), findsNothing);

    // Quello con orario è una casella nella griglia, **alla sua ora** (la quota
    // si legge dalla geometria: 8 * hourHeight dentro la timeline).
    expect(casellaInSettimana(), findsOneWidget);
    expect(
      tester.getTopLeft(casellaInSettimana()).dy -
          tester.getTopLeft(find.byType(WeekTimeline)).dy,
      closeTo(8 * DayTimeline.defaultHourHeight, 1),
      reason: 'la casella sta nella fascia delle 8',
    );

    // Quello **senza** orario non ha un'ora: sta nella fascia sopra la griglia.
    expect(find.text('Senza orario'), findsOneWidget);
  });

  testWidgets('in settimana «pieni», una casella fatta resta sbiadita',
      (tester) async {
    await todos.addTodo(
      title: 'Con orario',
      dueDate: giorno,
      startMinutes: 8 * 60,
    );
    await todos.toggleTodo(todos.todos.single.id);
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TodoCompactRow>(casellaInSettimana()).done,
      isTrue,
    );
  });

  testWidgets('in settimana «nascosta»: nessun todo da nessuna parte',
      (tester) async {
    await todos.addTodo(
      title: 'Con orario',
      dueDate: giorno,
      startMinutes: 8 * 60,
    );
    await todos.addTodo(title: 'Senza orario', dueDate: giorno);
    settings.setTodoInCalendario(TodoInCalendario.nascosta);
    await pumpCalendario(tester);

    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    expect(find.byType(DayTodoSection), findsNothing);
    expect(casellaInSettimana(), findsNothing);
    expect(find.text('Senza orario'), findsNothing);
  });

  testWidgets('in settimana «pieni» oltre due elementi: casella + bollino «+2»',
      (tester) async {
    // Lunedì 14: evento 9-10, e due todo che lo incrociano → un cluster di tre.
    // Prima i todo stavano a piena colonna sopra tutto («si compenetrano").
    // Ora il contratto settimana: **due riquadri al massimo** — il primo
    // elemento resta casella e il secondo riquadro fa il bollino «+N» (qui
    // «+2»), col foglio che poi mostra il cluster intero.
    await events.addEvent(
      title: 'Lezione',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    );
    await todos.addTodo(
      title: 'Studio',
      dueDate: giorno,
      startMinutes: 9 * 60 + 30,
      endMinutes: 10 * 60 + 30,
    );
    await todos.addTodo(
      title: 'Tema',
      dueDate: giorno,
      startMinutes: 9 * 60 + 45,
      endMinutes: 10 * 60 + 45,
    );
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    final righe = find.descendant(
      of: find.byType(WeekTimeline),
      matching: find.byType(TodoCompactRow),
    );
    expect(righe, findsNothing,
        reason:
            'con più di due il secondo riquadro è il bollino, non una casella');
    expect(
      find.descendant(
        of: find.byType(WeekTimeline),
        matching: find.text('+2'),
      ),
      findsOneWidget,
      reason: 'gli altri due elementi stanno nel bollino',
    );

    final rettangoliEvento = [
      for (final blocco
          in tester.widgetList<WeekEventBlock>(find.byType(WeekEventBlock)))
        tester.getRect(find.byWidget(blocco)),
    ];
    expect(rettangoliEvento, isNotEmpty,
        reason: 'l' "'" 'evento c\'è nella settimana');

    // Casella e bollino stanno in due riquadri disgiunti: mai sovrapposti.
    final bollino = find.descendant(
      of: find.byType(WeekTimeline),
      matching: find.byType(ClusterBadge),
    );
    expect(bollino, findsOneWidget);
    expect(
      tester.getRect(bollino).overlaps(rettangoliEvento.single),
      isFalse,
      reason: 'due riquadri, una corsia ciascuno: niente compenetrazione',
    );
  });

  testWidgets('in «giorno» due todo sovrapposti si dividono in corsie',
      (tester) async {
    await todos.addTodo(
      title: 'Studio',
      dueDate: giorno,
      startMinutes: 8 * 60,
      endMinutes: 9 * 60,
    );
    await todos.addTodo(
      title: 'Tema',
      dueDate: giorno,
      startMinutes: 8 * 60 + 30,
      endMinutes: 9 * 60 + 30,
    );
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    await tester.tap(find.text('Giorno'));
    await tester.pumpAndSettle();

    final righe = casellaNellaGriglia();
    expect(righe, findsNWidgets(2));
    final rettangoli = [
      for (final riga in tester.widgetList<TodoCompactRow>(righe))
        tester.getRect(find.byWidget(riga)),
    ];
    expect(
      rettangoli[0].overlaps(rettangoli[1]),
      isFalse,
      reason: 'nella colonna dei todo la sovrapposizione si divide',
    );
  });

  testWidgets('con «nascosta» la scheda Todo resta completa', (tester) async {
    settings.setTodoInCalendario(TodoInCalendario.nascosta);
    // Data **futura** di proposito: qui si prova che la scheda mostra i todo
    // anche quando il calendario li nasconde — non che gli scaduti stiano in
    // fascia (quello lo prova todo_page_test). Con una data passata la riga
    // finirebbe nella fascia «Scaduti», che parte chiusa.
    await todos.addTodo(title: 'Bolletta', dueDate: DateTime(2030, 9, 14));

    // Lo schermo di prova e' 800x600: l'elenco e' pigro, e con la riga sotto la
    // piega non la costruirebbe nemmeno. Come sui telefoni veri, si allarga.
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: providers(),
        child: const MaterialApp(home: TodoPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bolletta'), findsOneWidget);
  });

  testWidgets(
      'la cella del todo in griglia: niente pallino, titolo a tutta larghezza',
      (tester) async {
    await todos.addTodo(
      title: 'Pulire la cucina con tanto di forno',
      dueDate: giorno,
      startMinutes: 9 * 60,
      endMinutes: 10 * 60,
      priority: 2,
    );
    settings.setTodoInCalendario(TodoInCalendario.pieni);
    await pumpCalendario(tester);

    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    final riga = casellaInSettimana();
    expect(riga, findsOneWidget);

    // Il pallino è sparito: era lui a mangiare la riga («non si legge nulla»).
    expect(
      find.descendant(of: riga, matching: find.byType(TodoCheck)),
      findsNothing,
      reason: 'niente cerchio nella cella della griglia',
    );

    // Titolo + orario, col trattamento degli eventi: il titolo prende quasi
    // tutta la cella (prima pallino e spazi gliene lasciavano la metà).
    final testi = tester.widgetList<Text>(
      find.descendant(of: riga, matching: find.byType(Text)),
    );
    expect(testi, hasLength(2), reason: 'titolo e orario');
    final titolo =
        tester.widget<Text>(find.text('Pulire la cucina con tanto di forno'));
    expect(titolo.style?.fontSize, AppType.micro,
        reason: 'lo stesso trattamento del blocco evento');

    final rettRiga = tester.getRect(riga);
    final rettTitolo =
        tester.getRect(find.text('Pulire la cucina con tanto di forno'));
    expect(
      rettTitolo.width,
      greaterThan(rettRiga.width * 0.6),
      reason: 'la scritta occupa tutta la cella',
    );

    // I colori restano come sono: tinta neutra del todo (non scelta)…
    final ctx = tester.element(riga);
    final materiale = tester.widget<Material>(
      find.descendant(of: riga, matching: find.byType(Material)),
    );
    expect(
      materiale.color,
      Theme.of(ctx).colorScheme.surfaceContainerHigh.withValues(alpha: 0.20),
    );
    // …e barretta della priorità invariata.
    final contenitori = tester.widgetList<Container>(
      find.descendant(of: riga, matching: find.byType(Container)),
    );
    final barretta = contenitori.firstWhere(
      (c) =>
          c.decoration is BoxDecoration &&
          (c.decoration! as BoxDecoration).color != null,
    );
    expect(
      (barretta.decoration! as BoxDecoration).color,
      priorityColorFrom(defaultPriorityColors, 2),
      reason: 'la barretta della priorità è sempre quella',
    );
  });
}
