import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/sync/sync_service.dart';
import 'package:planner/core/sync/unconfigured_sync_auth.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/sync/sync_controller.dart';
import 'package:planner/features/todos/todo_overdue.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/app_shell.dart';

/// La richiesta degli scaduti compare **all'apertura**, una volta sola, e solo
/// se c'è qualcosa da confermare.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester, TodoProvider todos) async {
    final settings = AppSettingsController(db.settings)..load();
    final palettes = PaletteController(db)
      ..load()
      ..allineaPresets();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: palettes),
          ChangeNotifierProvider(create: (_) => EventProvider(db)),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ChangeNotifierProvider(create: (_) => NoteProvider(db)),
          ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
          ChangeNotifierProvider(
            create: (_) => SyncController(
              auth: const UnconfiguredSyncAuthService(),
              sync: SyncService(db),
              createGateway: () => throw StateError('non configurato'),
            ),
          ),
        ],
        child: const AppShell(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("un todo scaduto fa comparire la richiesta all'apertura",
      (tester) async {
    final todos = TodoProvider(db);
    // Due giorni fa: scaduto qualunque sia l'ora in cui gira il test.
    await todos.addTodo(
      title: 'Bolletta',
      dueDate: DateTime.now().subtract(const Duration(days: 2)),
    );

    await pumpApp(tester, todos);

    expect(find.text('Da confermare: 1 To do'), findsOneWidget);
    expect(find.text('Scaduti da confermare'), findsNothing);
    await tester.tap(find.text('Vedi'));
    await tester.pumpAndSettle();
    expect(find.text('Scaduti da confermare'), findsOneWidget);
    expect(find.text('Bolletta'), findsOneWidget);
  });

  testWidgets('senza scaduti non compare niente', (tester) async {
    final todos = TodoProvider(db);
    await todos.addTodo(
        title: 'Domani', dueDate: DateTime.now().add(const Duration(days: 1)));

    await pumpApp(tester, todos);

    expect(find.text('Scaduti da confermare'), findsNothing);
  });

  testWidgets('il riepilogo degli scaduti lascia liberi i comandi',
      (tester) async {
    final todos = TodoProvider(db);
    await todos.addTodo(
      title: 'Bolletta',
      dueDate: DateTime.now().subtract(const Duration(days: 2)),
    );

    await pumpApp(tester, todos);
    expect(find.text('Da confermare: 1 To do'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();

    expect(find.text('Da confermare: 1 To do'), findsNothing);
  });

  testWidgets('rispondere «No» chiude la richiesta, che non torna subito',
      (tester) async {
    final todos = TodoProvider(db);
    await todos.addTodo(
      title: 'Bolletta',
      dueDate: DateTime.now().subtract(const Duration(days: 2)),
    );

    await pumpApp(tester, todos);
    expect(find.text('Da confermare: 1 To do'), findsOneWidget);
    expect(find.text('Scaduti da confermare'), findsNothing);
    await tester.tap(find.text('Vedi'));
    await tester.pumpAndSettle();
    expect(find.text('Scaduti da confermare'), findsOneWidget);

    await tester.tap(find.text('Non ora'));
    await tester.pumpAndSettle();

    // Chiusa, e la sessione non la ripropone: torna alla prossima apertura.
    expect(find.text('Scaduti da confermare'), findsNothing);
    expect(todos.overdue(30, until: DateTime.now()), hasLength(1));
  });
}
