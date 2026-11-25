import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/notes/note_attachment_store.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/notes/domain/note.dart';
import 'package:planner/ui/mobile/note_editor_page.dart';

/// Regressione della perdita dati: l'editor apriva con 'Titolo'/'Contenuto...'
/// scritti a mano, non leggeva la nota dal database e non salvava mai.
void main() {
  late DatabaseService db;
  late NoteProvider provider;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    provider = NoteProvider(db);
  });

  tearDown(() => db.close());

  /// Apre l'editor spingendolo su una rotta, così il ritorno indietro è reale.
  Future<void> openEditor(WidgetTester tester, String noteId,
      {bool narrow = false}) async {
    final note = provider.byId(noteId)!;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NoteProvider>.value(value: provider),
          if (narrow)
            Provider.value(
                value: NoteAttachmentStore(db, Directory.systemTemp)),
        ],
        child: MaterialApp(
          builder: narrow
              ? (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(2),
                    ),
                    child: child!,
                  )
              : null,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => NoteEditorPage(note: note),
                    ),
                  ),
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra il contenuto reale e autosalva senza Salva',
      (tester) async {
    final note =
        await provider.addNote(title: 'Spesa', content: 'latte e pane');

    await openEditor(tester, note.id);

    // Il contenuto vero, non i segnaposto di prima.
    expect(find.text('Spesa'), findsOneWidget);
    expect(find.text('latte e pane'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('note-content')),
      'solo pane',
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // L'indicatore dice che è salvato, senza un bottone da premere.
    expect(find.text('Salvato'), findsOneWidget);

    // Rilettura da una nuova istanza: la prova che il dato è nel database.
    final fresh = NoteProvider(db);
    expect(fresh.byId(note.id)!.content, 'solo pane');

    // Uscendo non c'è nessuna richiesta da confermare.
    await tester.tap(find.byKey(const ValueKey('indietro-nota')));
    await tester.pumpAndSettle();
    expect(find.text('apri'), findsOneWidget);
    expect(find.text('Uscire senza salvare?'), findsNothing);
  });

  testWidgets('spazio pieno conserva la bozza aperta finché si può salvare',
      (tester) async {
    final failing = _NoteProviderWithStorageFailure(db);
    provider = failing;
    final note = await provider.addNote(title: 'Titolo', content: 'Prima');
    await openEditor(tester, note.id);
    await tester.enterText(
        find.byKey(const ValueKey('note-content')), 'Bozza nuova');
    failing.diskFull = true;
    await tester.tap(find.byKey(const ValueKey('indietro-nota')));
    await tester.pumpAndSettle();

    expect(find.text('Bozza nuova'), findsOneWidget);
    expect(find.text('Non salvato'), findsOneWidget);
    expect(
        find.textContaining('Spazio sul dispositivo esaurito'), findsOneWidget);
    expect(NoteProvider(db).byId(note.id)?.content, 'Prima');

    failing.diskFull = false;
    await tester.tap(find.byKey(const ValueKey('indietro-nota')));
    await tester.pumpAndSettle();
    expect(find.text('apri'), findsOneWidget);
    expect(NoteProvider(db).byId(note.id)?.content, 'Bozza nuova');
  });

  testWidgets('la toolbar trasforma il blocco in checklist', (tester) async {
    final note = await provider.addNote(title: 'Spesa', content: 'latte');
    await openEditor(tester, note.id);

    await tester.tap(find.byKey(const ValueKey('nota-checklist')));
    await tester.pump();

    // La casella è una Checkbox vera, non i caratteri "- [ ]".
    expect(find.byType(Checkbox), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(provider.byId(note.id)!.content, '- [x] latte');
  });

  testWidgets('Invio spezza il blocco e crea una riga nuova', (tester) async {
    final note = await provider.addNote(title: 'Spesa', content: 'latte');
    await openEditor(tester, note.id);

    await tester.enterText(
      find.byKey(const ValueKey('note-content')),
      'latte\npane',
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(provider.byId(note.id)!.content, 'latte\npane');
    // Titolo + due blocchi.
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('la toolbar trasforma il blocco in titolo', (tester) async {
    final note = await provider.addNote(title: 'Spesa', content: 'latte');
    await openEditor(tester, note.id);

    await tester.tap(find.byKey(const ValueKey('nota-titolo')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(provider.byId(note.id)!.content, '# latte');
  });

  testWidgets('Backspace a inizio blocco unisce al precedente', (tester) async {
    final note = await provider.addNote(title: 'Spesa', content: 'latte');
    await openEditor(tester, note.id);

    // Invio crea un secondo blocco vuoto, con il cursore all'inizio.
    await tester.enterText(
      find.byKey(const ValueKey('note-content')),
      'latte\n',
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(provider.byId(note.id)!.content, 'latte');
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('Rientro compare sull’elenco e conserva selezione e tastiera',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final note = await provider.addNote(title: 'Spesa', content: 'latte');
    await openEditor(tester, note.id, narrow: true);

    const key = ValueKey('nota-rientro');
    expect(find.byKey(key), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nota-puntato')));
    await tester.pumpAndSettle();
    final campo = find.byKey(const ValueKey('blocco-1'));
    final editor = tester.widget<TextField>(campo);
    const selezione = TextSelection(baseOffset: 1, extentOffset: 3);
    editor.controller!.selection = selezione;
    expect(tester.testTextInput.isVisible, isTrue);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(find.text('Chiudi la tastiera'), findsNothing);
    expect(find.text('Sposta a destra'), findsOneWidget);
    expect(find.text('Sposta a sinistra'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nota-rientro-piu')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(provider.byId(note.id)!.content, '  - latte');
    expect(editor.focusNode!.hasFocus, isTrue);
    expect(editor.controller!.selection, selezione);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nota-rientro-meno')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(provider.byId(note.id)!.content, '- latte');
    expect(editor.controller!.selection, selezione);

    await tester.tap(find.byKey(const ValueKey('note-title')));
    await tester.pumpAndSettle();
    expect(find.byKey(key), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dal menu si fissa la nota, senza perdere il contenuto',
      (tester) async {
    final note = await provider.addNote(title: 'Spesa', content: 'latte');
    await openEditor(tester, note.id);

    await tester.tap(find.byKey(const ValueKey('menu-nota')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nota-pin')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(provider.byId(note.id)!.pinned, isTrue);
    expect(provider.byId(note.id)!.content, 'latte');
    // Il menu ora offre l'azione inversa: il comando è vivo, non decorativo.
    await tester.tap(find.byKey(const ValueKey('menu-nota')));
    await tester.pumpAndSettle();
    expect(find.text('Rimuovi dalle fissate'), findsOneWidget);
  });

  testWidgets('colore ed evidenziatore si salvano e compaiono in anteprima',
      (tester) async {
    final note =
        await provider.addNote(title: 'Nota', content: 'prima\nseconda');
    await openEditor(tester, note.id);
    final field = find.byKey(const ValueKey('blocco-2'));
    final tool = find.byKey(const ValueKey('nota-formato-testo'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(tool);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blu'));
    await tester.pumpAndSettle();
    await tester.tap(tool);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attiva o togli evidenziazione'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(field);
    expect(input.controller?.text, 'seconda');
    expect(input.style?.color, const Color(0xff124e9a));
    expect(input.style?.backgroundColor, const Color(0xffffed99));
    expect(provider.byId(note.id)!.content,
        'prima\nseconda<!--planner-text:v1:blue:1-->');
    await tester.tap(find.byKey(const ValueKey('menu-nota')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nota-anteprima')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('seconda')).style?.backgroundColor,
        const Color(0xffffed99));
  });

  testWidgets('annulla e ripristina riportano il contenuto', (tester) async {
    final note = await provider.addNote(title: 'Spesa', content: 'latte');
    await openEditor(tester, note.id);

    await tester.enterText(
      find.byKey(const ValueKey('note-content')),
      'latte e pane',
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nota-undo')));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(provider.byId(note.id)!.content, 'latte');

    await tester.tap(find.byKey(const ValueKey('nota-redo')));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(provider.byId(note.id)!.content, 'latte e pane');
  });

  testWidgets('in modalità Leggi spunta una checkbox e salva', (tester) async {
    final note = await provider.addNote(
      title: 'Spesa',
      content: 'Fare:\n- [ ] latte\n- [ ] pane',
    );
    await openEditor(tester, note.id);

    await tester.tap(find.byKey(const ValueKey('menu-nota')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nota-anteprima')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('check-nota-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('check-nota-1')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(provider.byId(note.id)!.content, contains('- [x] latte'));
  });

  testWidgets('autosave salva dopo la pausa', (tester) async {
    final note = await provider.addNote(title: 'Spesa', content: 'latte');
    await openEditor(tester, note.id);

    await tester.enterText(
      find.byKey(const ValueKey('note-content')),
      'latte e pane',
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(provider.byId(note.id)!.content, 'latte e pane');
  });

  testWidgets('uscire con modifiche le salva, senza chiedere conferma',
      (tester) async {
    final note = await provider.addNote(title: 'Spesa', content: 'latte');
    await openEditor(tester, note.id);

    await tester.enterText(
      find.byKey(const ValueKey('note-title')),
      'Modificato',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('indietro-nota')));
    await tester.pumpAndSettle();

    // Nessun dialogo: l'editor ha già salvato uscendo.
    expect(find.text('Uscire senza salvare?'), findsNothing);
    expect(find.text('apri'), findsOneWidget);
    final fresh = NoteProvider(db);
    expect(fresh.byId(note.id)!.title, 'Modificato');
  });

  for (final scala in [1.3, 2.0]) {
    testWidgets('a scala testo $scala non trabocca', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scala;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final note = await provider.addNote(
        title: 'Spesa della settimana',
        content: 'latte e pane',
      );
      await openEditor(tester, note.id);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('note-content')), findsOneWidget);
    });
  }

  testWidgets('uscire senza modifiche non chiede nulla', (tester) async {
    final note = await provider.addNote(title: 'Spesa', content: 'latte');
    await openEditor(tester, note.id);

    await tester.tap(find.byKey(const ValueKey('indietro-nota')));
    await tester.pumpAndSettle();

    expect(find.text('Uscire senza salvare?'), findsNothing);
    expect(find.text('apri'), findsOneWidget);
  });
}

class _NoteProviderWithStorageFailure extends NoteProvider {
  _NoteProviderWithStorageFailure(super.db);
  bool diskFull = false;

  @override
  Future<void> updateNote(Note note) async {
    if (diskFull) throw SqliteException(13, 'technical details');
    await super.updateNote(note);
  }
}
