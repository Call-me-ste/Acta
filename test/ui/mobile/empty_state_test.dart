import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/agenda_page.dart';
import 'package:planner/ui/mobile/notes_page.dart';
import 'package:planner/ui/mobile/todo_page.dart';

import '../../support/theme_providers.dart';

/// Lo stato vuoto deve essere centrato **nei due sensi**: icona e scritta a metà
/// schermo, non appoggiate a sinistra. Un test che guarda le coordinate, perché
/// "sembra centrato" e "è centrato" sono due cose diverse — ed è esattamente il
/// difetto che si vedeva a occhio su Todo e Agenda.
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
    List<SingleChildWidget> providers,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(providers: providers, child: MaterialApp(home: page)),
    );
    await tester.pumpAndSettle();
  }

  void expectCentrato(WidgetTester tester, Finder finder, String cosa) {
    final schermo = tester.getRect(find.byType(MaterialApp));
    final rect = tester.getRect(finder);
    expect(
      rect.center.dx,
      closeTo(schermo.center.dx, 1),
      reason:
          '$cosa non è centrato: centro ${rect.center.dx} su ${schermo.center.dx}',
    );
  }

  testWidgets('todo vuoto: icona e scritta centrate', (tester) async {
    await pumpPage(tester, const TodoPage(), [
      ChangeNotifierProvider(create: (_) => TodoProvider(db)),
      ...themeProviders(db),
    ]);

    expectCentrato(tester, find.byIcon(Icons.checklist_outlined), "l'icona");
    expectCentrato(tester, find.text('Nessun To do'), 'la scritta');
  });

  testWidgets('agenda vuota: icona e scritta centrate', (tester) async {
    await pumpPage(tester, const AgendaPage(), [
      ChangeNotifierProvider(create: (_) => EventProvider(db)),
      // L'agenda mostra anche i todo (dal #91): senza il provider la pagina non
      // si costruisce, ed è giusto cosi' — sono dati che le servono.
      ChangeNotifierProvider(create: (_) => TodoProvider(db)),
      ...themeProviders(db),
    ]);

    expectCentrato(
      tester,
      find.byIcon(Icons.view_agenda_outlined),
      "l'icona",
    );
    expectCentrato(tester, find.text('Niente in programma'), 'la scritta');
  });

  // La sezione Note ora e' una pagina vera: senza note mostra lo stesso stato
  // vuoto condiviso, con la ricerca sopra.
  testWidgets('note: lo stato vuoto centrato', (tester) async {
    await pumpPage(tester, const NotesPage(), [
      ChangeNotifierProvider(create: (_) => NoteProvider(db)),
      ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
      ...themeProviders(db),
    ]);

    expectCentrato(tester, find.byIcon(Icons.edit_note_outlined), "l'icona");
    expectCentrato(tester, find.text('Nessuna nota'), 'la scritta');
  });
}
