import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/domain/note_folder.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/note_selection.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/note_editor_page.dart';
import 'package:planner/ui/mobile/notes_page.dart';

void main() {
  late DatabaseService db;
  late NoteProvider provider;
  late EventProvider eventi;
  late TodoProvider todos;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    provider = NoteProvider(db);
    eventi = EventProvider(db);
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  Future<void> apri(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NoteProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
          ChangeNotifierProvider<EventProvider>.value(value: eventi),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
        ],
        child: const MaterialApp(home: NotesPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('elenca e cerca per titolo e contenuto', (tester) async {
    await provider.addNote(title: 'Spesa', content: 'latte e pane');
    await provider.addNote(title: 'Idee', content: 'app planner');
    await apri(tester);

    expect(find.text('Spesa'), findsOneWidget);
    expect(find.text('Idee'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('cerca-note')), 'latte');
    await tester.pump();
    expect(find.text('Spesa'), findsOneWidget);
    expect(find.text('Idee'), findsNothing);
  });

  testWidgets('filtra per cartella e per senza cartella', (tester) async {
    final folder = await provider.addFolder(name: 'Lavoro');
    await provider.addNote(title: 'Riunione', folderId: folder.id);
    await provider.addNote(title: 'Idee');
    await apri(tester);

    expect(find.text('Riunione'), findsOneWidget);
    expect(find.text('Idee'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('folder-chip-${folder.id}')));
    await tester.pump();
    expect(find.text('Riunione'), findsOneWidget);
    expect(find.text('Idee'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('folder-chip-senza')));
    await tester.pump();
    expect(find.text('Riunione'), findsNothing);
    expect(find.text('Idee'), findsOneWidget);
  });

  testWidgets('selezione multipla: pin di due note', (tester) async {
    final a = await provider.addNote(title: 'Prima');
    final b = await provider.addNote(title: 'Seconda');
    await apri(tester);

    await tester.longPress(find.text('Prima'));
    await tester.pumpAndSettle();
    expect(find.text('1 selezionate'), findsOneWidget);
    await tester.tap(find.text('Seconda'));
    await tester.pumpAndSettle();
    expect(find.text('2 selezionate'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note-pin-selezione')));
    await tester.pumpAndSettle();

    expect(provider.byId(a.id)!.pinned, isTrue);
    expect(provider.byId(b.id)!.pinned, isTrue);
    expect(find.text('1 selezionate'), findsNothing);
  });

  testWidgets('selezione multipla: sposta in cartella', (tester) async {
    final folder = await provider.addFolder(name: 'Lavoro');
    final nota = await provider.addNote(title: 'Riunione');
    await apri(tester);

    await tester.longPress(find.text('Riunione'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-sposta-selezione')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lavoro').last);
    await tester.pumpAndSettle();

    expect(provider.byId(nota.id)!.folderId, folder.id);
  });

  testWidgets('selezione multipla: elimina con conferma', (tester) async {
    final nota = await provider.addNote(title: 'Da eliminare');
    await apri(tester);

    await tester.longPress(find.text('Da eliminare'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-elimina-selezione')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(provider.byId(nota.id), isNull);
  });

  testWidgets('ordina per titolo', (tester) async {
    await provider.addNote(title: 'Alfa');
    await provider.addNote(title: 'Zeta');
    await apri(tester);

    await tester.tap(find.byKey(const ValueKey('ordina-note')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ordine-titolo')));
    await tester.pumpAndSettle();

    final alfa = tester.getTopLeft(find.text('Alfa')).dy;
    final zeta = tester.getTopLeft(find.text('Zeta')).dy;
    expect(alfa, lessThan(zeta));
  });

  testWidgets('lo swipe a destra fissa la nota e la mette in cima',
      (tester) async {
    final prima = await provider.addNote(title: 'Prima');
    await provider.addNote(title: 'Seconda');
    await apri(tester);

    await tester.drag(find.text('Prima'), const Offset(420, 0));
    await tester.pumpAndSettle();

    expect(provider.notes.first.id, prima.id);
    expect(provider.notes.first.pinned, isTrue);
    expect(find.text('Fissate'), findsOneWidget);
  });

  testWidgets('lo swipe a sinistra elimina dopo la conferma', (tester) async {
    final nota = await provider.addNote(title: 'Da swipe');
    await apri(tester);

    await tester.drag(find.text('Da swipe'), const Offset(-420, 0));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare la nota?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Elimina'));
    await tester.pumpAndSettle();

    expect(provider.byId(nota.id), isNull);
  });

  testWidgets("l'editor sposta la nota in una cartella", (tester) async {
    final folder = await provider.addFolder(name: 'Lavoro');
    final note = await provider.addNote(title: 'Riunione');
    await apri(tester);

    await tester.tap(find.text('Riunione'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cartella-nota')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lavoro').last);
    await tester.pumpAndSettle();

    expect(provider.byId(note.id)!.folderId, folder.id);
  });

  testWidgets('il picker collega un\'altra nota e la mostra da entrambe',
      (tester) async {
    final a = await provider.addNote(title: 'Nota A');
    final b = await provider.addNote(title: 'Nota B');
    await provider.linkNote(
      noteId: a.id,
      entityType: 'note',
      entityId: b.id,
    );
    await apri(tester);

    await tester.tap(find.text('Nota A'));
    await tester.pumpAndSettle();
    expect(find.text('Nota B'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('indietro-nota')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nota B'));
    await tester.pumpAndSettle();
    // Il collegamento è bidirezionale in lettura: B vede A.
    expect(find.text('Nota A'), findsOneWidget);
  });

  testWidgets('il picker Note collega la nota scelta', (tester) async {
    final a = await provider.addNote(title: 'Nota A');
    final b = await provider.addNote(title: 'Nota B');
    await apri(tester);

    await tester.tap(find.text('Nota A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-nota')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('collega-nota')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('link-note-${b.id}')));
    await tester.pumpAndSettle();

    expect(provider.linksOfNote(a.id), hasLength(1));
    expect(provider.linksOfNote(a.id).single.entityType, 'note');
  });

  testWidgets("l'editor mostra il collegamento a un todo", (tester) async {
    await todos.addTodo(title: 'Comprare latte');
    final todo = todos.todos.single;
    final note = await provider.addNote(title: 'Spesa');
    await provider.linkNote(
      noteId: note.id,
      entityType: 'todo',
      entityId: todo.id,
    );
    await apri(tester);

    await tester.tap(find.text('Spesa'));
    await tester.pumpAndSettle();

    expect(find.text('Collegamenti'), findsOneWidget);
    expect(find.text('Comprare latte'), findsOneWidget);
  });

  testWidgets('mostra l\'azione smart per una data nella nota', (tester) async {
    await provider.addNote(
      title: 'Riunione',
      content: 'Riunione il 14/10 alle 9',
    );
    await apri(tester);

    await tester.tap(find.text('Riunione'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('smart-crea-evento')), findsOneWidget);
  });

  testWidgets('suggerisce un collegamento dalla nota', (tester) async {
    await todos.addTodo(title: 'Comprare latte');
    final todo = todos.todos.single;
    final note = await provider.addNote(
      title: 'Spesa',
      content: 'Comprare latte e pane',
    );
    await apri(tester);

    await tester.tap(find.text('Spesa'));
    await tester.pumpAndSettle();

    final chip = find.byKey(
      ValueKey('suggerimento-todo|${todo.id}'),
    );
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(provider.linksOfNote(note.id), hasLength(1));
  });

  testWidgets('il picker collega un todo alla nota', (tester) async {
    await todos.addTodo(title: 'Comprare latte');
    final note = await provider.addNote(title: 'Spesa');
    await apri(tester);

    await tester.tap(find.text('Spesa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-nota')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('collega-nota')));
    await tester.pumpAndSettle();

    expect(find.text('Collega a…'), findsWidgets);
    await tester.tap(find.text('To do'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comprare latte'));
    await tester.pumpAndSettle();

    expect(provider.linksOfNote(note.id), hasLength(1));
    expect(find.text('Comprare latte'), findsOneWidget);
  });

  testWidgets("Nuova nota apre l'editor e la persiste", (tester) async {
    await apri(tester);
    await tester.tap(find.byKey(const ValueKey('crea')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('crea-nota')));
    await tester.pumpAndSettle();

    expect(find.byType(NoteEditorPage), findsOneWidget);
    expect(provider.notes, hasLength(1));
  });

  testWidgets('il + offre nota e cartella nello stesso foglio', (tester) async {
    await apri(tester);

    await tester.tap(find.byKey(const ValueKey('crea')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('crea-nota')), findsOneWidget);
    expect(find.byKey(const ValueKey('crea-cartella')), findsOneWidget);
  });

  testWidgets('l\'anteprima non mostra il markdown', (tester) async {
    await provider.addNote(
      title: 'Lista',
      content: '- [x] latte\n- [ ] pane',
    );
    await apri(tester);

    expect(find.text('latte · pane'), findsOneWidget);
    expect(find.textContaining('- [x]'), findsNothing);
  });

  testWidgets('i tag filtrano l\'elenco e il foglio li mostra tutti',
      (tester) async {
    await provider.addNote(title: 'Spesa', content: '#casa latte');
    await provider.addNote(title: 'Ufficio', content: '#lavoro riunione');
    await provider.addNote(title: 'Idee', content: 'senza tag');
    await apri(tester);

    expect(find.byKey(const ValueKey('tag-casa')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tag-casa')));
    await tester.pumpAndSettle();

    expect(find.text('Spesa'), findsOneWidget);
    expect(find.text('Ufficio'), findsNothing);
    expect(find.text('Idee'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tag-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tag-sheet-casa')), findsOneWidget);
    expect(find.byKey(const ValueKey('tag-sheet-lavoro')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tag-sheet-tutti')));
    await tester.pumpAndSettle();
    expect(find.text('Spesa'), findsOneWidget);
    expect(find.text('Idee'), findsOneWidget);
  });

  testWidgets('con molte cartelle la barra mostra le fissate, il foglio tutte',
      (tester) async {
    final folders = <NoteFolder>[];
    for (var i = 0; i < 4; i++) {
      folders.add(await provider.addFolder(name: 'Cartella $i'));
    }
    await provider.updateFolder(folders[1].copyWith(pinned: true));
    await provider.addNote(title: 'Dentro la prima', folderId: folders[0].id);
    await provider.addNote(title: 'Dentro la seconda', folderId: folders[1].id);
    await apri(tester);

    // Solo la fissata resta in barra; le altre stanno nel foglio.
    expect(find.byKey(ValueKey('folder-chip-${folders[0].id}')), findsNothing);
    expect(find.byKey(ValueKey('folder-chip-${folders[1].id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('folder-all')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('folder-all')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('cartella-sheet-${folders[0].id}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ValueKey('cartella-sheet-${folders[0].id}')));
    await tester.pumpAndSettle();
    expect(find.text('Dentro la prima'), findsOneWidget);
    expect(find.text('Dentro la seconda'), findsNothing);
  });
}

