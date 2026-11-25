import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/sync/sync_service.dart';
import 'package:planner/core/sync/unconfigured_sync_auth.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/sync/sync_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/app_shell.dart';
import 'package:planner/ui/mobile/bottom_bar.dart';
import 'package:planner/ui/mobile/month_view.dart';

import '../../support/theme_providers.dart';

/// Le schede del guscio: chi sta dietro la barra in basso **non si iscrive** ai
/// provider dei dati.
///
/// Perche' conta: l'`IndexedStack` tiene vive le schede visitate — e' quello che
/// fa sopravvivere il loro stato al cambio scheda — ma vuol dire anche che la
/// griglia del mese, con le sue 42 celle, resta nell'albero mentre si scrive un
/// todo nella scheda davanti. Misurato sul telefono: 26,4 ms di build per un
/// tocco su una card. Qui si conta in **ricostruzioni**, non in millisecondi: un
/// tempo preso in debug non vale niente, una ricostruzione mancata e' un fatto.
void main() {
  late DatabaseService db;
  late TodoProvider todos;
  late EventProvider events;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    todos = TodoProvider(db);
    events = EventProvider(db);
  });

  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...themeProviders(db),
          ChangeNotifierProvider<EventProvider>.value(value: events),
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

  /// La voce della barra in basso. `find.text` da solo non basta: «Todo» e
  /// «Calendario» sono parole che compaiono anche dentro le pagine.
  Finder voce(String etichetta) => find.descendant(
        of: find.byType(BottomBar),
        matching: find.text(etichetta),
      );

  MonthView mese(WidgetTester tester) =>
      tester.widget<MonthView>(find.byType(MonthView, skipOffstage: false));

  testWidgets(
      'con la scheda calendario nascosta una scrittura non ricostruisce le '
      'viste, e tornando si vedono i dati di adesso', (tester) async {
    await pumpApp(tester);
    expect(find.byType(MonthView, skipOffstage: false), findsOneWidget);
    expect(find.textContaining('To do del giorno'), findsNothing);

    final primaDelCambio = mese(tester);

    await tester.tap(voce('To do'));
    await tester.pumpAndSettle();

    // La scrittura che sul telefono apriva il fotogramma da 26,4 ms.
    await todos.addTodo(title: 'Pane', dueDate: DateTime.now());
    await tester.pumpAndSettle();

    expect(
      identical(mese(tester), primaDelCambio),
      isTrue,
      reason: 'la scheda che non si guarda non ascolta i provider dei dati',
    );
    expect(
      find.textContaining('To do del giorno'),
      findsNothing,
      reason: 'e resta com\'era: e\' fuori scena, nessuno la vede',
    );

    // Tornando in scena si allinea: la chiave della memoria porta la
    // generazione dei dati, quindi il mese si rifa' con quello che c'e' ora.
    await tester.tap(voce('Calendario'));
    await tester.pumpAndSettle();

    expect(
      identical(mese(tester), primaDelCambio),
      isFalse,
      reason: 'tornando attiva la vista si rifa\' sui dati di adesso',
    );
    expect(find.text('To do del giorno (1)'), findsOneWidget);
  });

  testWidgets('entrando nella scheda Todo si torna sempre su «Oggi»',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(voce('To do'));
    await tester.pumpAndSettle();

    // Si sceglie un'altra vista...
    await tester.tap(find.byKey(const ValueKey('cambia-vista')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vista-prossimi7')));
    await tester.pumpAndSettle();
    expect(find.text('Prossimi 7 giorni'), findsOneWidget);

    // ...si esce dalla scheda e si rientra: si riparte da **Oggi**, perche' chi
    // apre la scheda Todo sta cercando cosa fare adesso.
    await tester.tap(voce('Calendario'));
    await tester.pumpAndSettle();
    await tester.tap(voce('To do'));
    await tester.pumpAndSettle();

    expect(find.text('Oggi'), findsOneWidget);
    expect(find.text('Prossimi 7 giorni'), findsNothing);
  });

  testWidgets('con la scheda calendario davanti la scrittura si vede subito',
      (tester) async {
    await pumpApp(tester);
    expect(find.textContaining('To do del giorno'), findsNothing);

    await todos.addTodo(title: 'Pane', dueDate: DateTime.now());
    await tester.pumpAndSettle();

    expect(
      find.text('To do del giorno (1)'),
      findsOneWidget,
      reason: 'chi si guarda si aggiorna: l\'ottimizzazione non compra la '
          'freschezza',
    );
  });

  testWidgets('anche una scrittura di eventi non tocca il calendario nascosto',
      (tester) async {
    await pumpApp(tester);
    final primaDelCambio = mese(tester);

    await tester.tap(voce('To do'));
    await tester.pumpAndSettle();

    await events.addEvent(
      title: 'Palestra',
      start: DateTime.now().add(const Duration(hours: 1)),
      end: DateTime.now().add(const Duration(hours: 2)),
    );
    await tester.pumpAndSettle();

    expect(identical(mese(tester), primaDelCambio), isTrue);
  });

  testWidgets('l\'agenda davanti si aggiorna quando si scrive', (tester) async {
    await pumpApp(tester);
    await tester.tap(voce('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Palestra'), findsNothing);

    await events.addEvent(
      title: 'Palestra',
      start: DateTime.now().add(const Duration(hours: 1)),
      end: DateTime.now().add(const Duration(hours: 2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Palestra'), findsOneWidget);
  });
}
