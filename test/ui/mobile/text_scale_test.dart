import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/sync/sync_service.dart';
import 'package:planner/core/sync/unconfigured_sync_auth.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/sync/sync_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/agenda_page.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/note_folders_bar.dart';
import 'package:planner/ui/mobile/note_tags_bar.dart';
import 'package:planner/ui/mobile/notes_page.dart';
import 'package:planner/ui/mobile/settings_page.dart';
import 'package:planner/ui/mobile/todo_page.dart';

import '../../support/theme_providers.dart';

/// Le schermate principali con il **testo ingrandito** (1.3, come il telefono
/// dell'utente).
///
/// Un testo che non ci sta è un'informazione che sparisce, e la scala del testo
/// è una preferenza di accessibilità, non un caso limite. Le altezze fisse
/// (`daysOfWeekHeight`, `rowHeight` della griglia) sono già state corrette una
/// volta proprio da un test così.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page,
    List<SingleChildWidget> providers, {
    double scala = 1.3,
  }) async {
    // Telefono vero e testo ingrandito.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = scala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MultiProvider(providers: providers, child: MaterialApp(home: page)),
    );
    await tester.pumpAndSettle();
  }

  /// Dati veri: una schermata vuota non mette alla prova niente.
  Future<EventProvider> seededEvents() async {
    final events = EventProvider(db);
    final now = DateTime.now();
    await events.addEvent(
      title: 'Riunione di tutto il gruppo',
      start: now.add(const Duration(hours: 1)),
      end: now.add(const Duration(hours: 2)),
    );
    return events;
  }

  Future<TodoProvider> seededTodos() async {
    final todos = TodoProvider(db);
    await todos.addTodo(title: 'Bolletta della luce', dueDate: DateTime.now());
    return todos;
  }

  testWidgets('calendario a scala 1.3', (tester) async {
    await pumpPage(
      tester,
      const CalendarPage(),
      [
        Provider.value(value: db),
        ChangeNotifierProvider.value(value: await seededEvents()),
        ChangeNotifierProvider.value(value: await seededTodos()),
        ...themeProviders(db),
      ],
    );
    expect(tester.takeException(), isNull);
    final search = find.byTooltip('Cerca in Acta');
    final add = find.byTooltip('Nuovo');
    expect(tester.getBottomRight(search).dy, lessThan(tester.getTopLeft(add).dy));
    expect(tester.getCenter(search).dy,
        greaterThan(tester.getCenter(find.text('Mese')).dy));
    expect(tester.getCenter(search).dx, tester.getCenter(add).dx);
    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(find.text('Cerca in Acta'), findsOneWidget);
  });

  testWidgets('calendario a scala 2.0 con la lente sopra il pulsante di aggiunta',
      (tester) async {
    await pumpPage(
      tester,
      const CalendarPage(),
      [
        Provider.value(value: db),
        ChangeNotifierProvider.value(value: await seededEvents()),
        ChangeNotifierProvider.value(value: await seededTodos()),
        ...themeProviders(db),
      ],
      scala: 2,
    );
    expect(tester.takeException(), isNull);
    final search = find.byTooltip('Cerca in Acta');
    final add = find.byTooltip('Nuovo');
    expect(tester.getBottomRight(search).dy, lessThan(tester.getTopLeft(add).dy));
    expect(search.hitTestable(), findsOneWidget);
    expect(add.hitTestable(), findsOneWidget);
  });

  testWidgets('todo a scala 1.3', (tester) async {
    await pumpPage(
      tester,
      const TodoPage(),
      [
        ChangeNotifierProvider.value(value: await seededTodos()),
        ...themeProviders(db),
      ],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cartelle e tag delle Note hanno la stessa altezza a scala 2,0',
      (tester) async {
    final notes = NoteProvider(db);
    await notes.addNote(title: '#progetto');
    await notes.addFolder(name: 'Lavoro');
    await pumpPage(
      tester,
      const NotesPage(),
      [
        ChangeNotifierProvider.value(value: notes),
        ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
        ...themeProviders(db),
      ],
      scala: 2,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(NoteFoldersBar)).height,
      tester.getSize(find.byType(NoteTagsBar)).height,
    );
  });

  testWidgets('agenda a scala 1.3', (tester) async {
    await pumpPage(
      tester,
      const AgendaPage(),
      [
        ChangeNotifierProvider.value(value: await seededEvents()),
        // I todo del giorno fanno parte dell'agenda dal #91.
        ChangeNotifierProvider.value(value: await seededTodos()),
        ...themeProviders(db),
      ],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('impostazioni a scala 1.3', (tester) async {
    await pumpPage(
      tester,
      const SettingsPage(),
      [
        ChangeNotifierProvider(
          create: (_) => SyncController(
            auth: const UnconfiguredSyncAuthService(),
            sync: SyncService(db),
            createGateway: () => throw StateError('non configurato'),
          ),
        ),
        ...themeProviders(db),
      ],
    );
    expect(tester.takeException(), isNull);
  });
}
