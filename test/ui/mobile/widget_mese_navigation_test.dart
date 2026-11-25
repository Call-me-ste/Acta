import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/calendar/giorno_richiesto.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/widgets/widget_contract.dart';
import 'package:planner/ui/mobile/calendar_page.dart';
import 'package:planner/ui/mobile/mobile_shell.dart';
import 'package:planner/ui/shared/widget_guard.dart';

import '../../support/fake_widget_bridge.dart';
import '../../support/theme_providers.dart';

/// Il tocco sul **giorno** del widget mensile: `planner://apri?giorno=…`.
///
/// Perché conta: è il caso che prima finiva nel vuoto — un URI senza elemento
/// veniva ignorato, e il widget sembrava rotto. Le tre cose da pretendere: l'URI
/// si legge, la richiesta arriva al calendario **anche se la scheda non c'era**,
/// e il giorno scelto è quello, non oggi.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  test('l\'URI del solo giorno si legge (e non è un elemento)', () {
    final tocca =
        leggiToccaDelWidget(Uri.parse('planner://apri?giorno=2026-11-13'));

    expect(tocca, isNotNull);
    expect(tocca!.azione, 'apri');
    expect(tocca.id, isNull);
    expect(tocca.tipo, isNull);
    expect(tocca.giorno, DateTime(2026, 11, 13));
  });

  testWidgets('la guardia trasforma l\'URI del giorno in una richiesta',
      (tester) async {
    final richiesta = GiornoRichiesto();
    final ponte = FakeWidgetBridge()
      ..avvio = Uri.parse('planner://apri?giorno=2026-11-13');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>(
              create: (_) => EventProvider(db)),
          ChangeNotifierProvider<TodoProvider>(create: (_) => TodoProvider(db)),
          ...themeProviders(db),
          ChangeNotifierProvider<GiornoRichiesto>.value(value: richiesta),
        ],
        child: MaterialApp(
          home: WidgetGuard(
            ponte: ponte,
            child: const Scaffold(body: SizedBox()),
          ),
        ),
      ),
    );
    // Il primo fotogramma: la guardia parte da lì.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(richiesta.giorno, DateTime(2026, 11, 13),
        reason: 'il giorno del widget arriva al calendario');

    // E il pacchetto mensile e' stato pubblicato, con l'indice che dice al
    // Kotlin quale finestra e' valida: senza, il mese non comparirebbe mai.
    final adesso = DateTime.now();
    final corrente = DateTime(adesso.year, adesso.month);
    expect(ponte.dati[chiaveMese(corrente)], isNotNull,
        reason: 'il mese corrente viaggia col pacchetto');
    expect(ponte.dati[chiaveMesiPubblicati], contains(annoMeseIso(corrente)));
    expect(ponte.dati[chiaveMesiPubblicati],
        contains(annoMeseIso(DateTime(corrente.year, corrente.month - 1))));
    expect(ponte.dati[chiaveMesiPubblicati],
        contains(annoMeseIso(DateTime(corrente.year, corrente.month + 1))));
  });

  testWidgets('il calendario apre il mese del giorno chiesto e lo consuma',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final richiesta = GiornoRichiesto();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>(
              create: (_) => EventProvider(db)),
          ChangeNotifierProvider<TodoProvider>(create: (_) => TodoProvider(db)),
          ChangeNotifierProvider<NoteProvider>(create: (_) => NoteProvider(db)),
          ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
          ...themeProviders(db),
          ChangeNotifierProvider<GiornoRichiesto>.value(value: richiesta),
        ],
        child: const MaterialApp(home: MobileShell()),
      ),
    );
    await tester.pumpAndSettle();
    // Si parte da un'altra scheda: il tocco deve riportare il calendario in
    // scena, non solo cambiare una variabile.
    await tester.tap(find.text('Note').last);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarPage), findsNothing,
        reason: 'la scheda del calendario non è più in scena');

    richiesta.chiedi(DateTime(2026, 11, 13));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarPage), findsOneWidget,
        reason: 'il guscio torna sulla scheda del calendario');
    expect(find.textContaining('Novembre 2026'), findsOneWidget,
        reason: 'il mese mostrato è quello del giorno chiesto');
    expect(richiesta.giorno, isNull,
        reason: 'la richiesta si consuma una volta sola');
  });
}
