import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/ui/mobile/note_editor_page.dart';
import 'package:planner/ui/mobile/note_links_indicator.dart';

void main() {
  late DatabaseService db;
  late NoteProvider provider;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    provider = NoteProvider(db);
  });

  tearDown(() => db.close());

  testWidgets('mostra e apre le note collegate', (tester) async {
    final nota = await provider.addNote(title: 'Preparare valigia');
    await provider.linkNote(
      noteId: nota.id,
      entityType: 'event',
      entityId: 'evento-1',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<NoteProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: NoteLinksIndicator(
              noteProvider: provider,
              entityType: 'event',
              entityId: 'evento-1',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Note collegate (1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('note-collegate')));
    await tester.pumpAndSettle();

    expect(find.text('Note collegate'), findsOneWidget);
    await tester.tap(find.text('Preparare valigia'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteEditorPage), findsOneWidget);
  });

  testWidgets('senza note collegate non mostra niente', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteLinksIndicator(
            noteProvider: provider,
            entityType: 'event',
            entityId: 'evento-1',
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('note-collegate')), findsNothing);
  });
}
