import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notes/note_provider.dart';
import 'package:planner/features/search/item_search_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';

void main() {
  test('trova eventi, attività e note dalle rispettive informazioni', () async {
    final db = DatabaseService();
    await db.init(dbPath: ':memory:');
    addTearDown(db.close);
    final search = ItemSearchController(db);
    addTearDown(search.dispose);
    final notes = NoteProvider(db);
    final note = await notes.addNote();
    await notes.updateNote(note.copyWith(title: 'Spese', content: 'Caffè 5%'));
    await EventProvider(db).addEvent(
      title: 'Riunione',
      start: DateTime(2026, 11, 25, 9),
      end: DateTime(2026, 11, 25, 10),
      location: 'Caffè Centrale',
    );
    await TodoProvider(db).addTodo(title: 'CAFFÈ', note: 'Portare la ricevuta');

    search.setQuery('  caffè  ');
    await search.refresh();
    expect(search.results.map((item) => item.kind).toSet(),
        SearchKind.values.toSet());
    expect(search.results.first.kind, SearchKind.todo);
    search.setQuery('5%');
    await search.refresh();
    expect(search.results.single.id, note.id);
    expect(search.read(search.results.single), isNotNull);
    search.setQuery('');
    expect(search.results, isEmpty);
  });

  test('la ricerca su disco pubblica solo la risposta ancora richiesta',
      () async {
    final directory = await Directory.systemTemp.createTemp('acta-search-');
    addTearDown(() => directory.delete(recursive: true));
    final db = DatabaseService();
    await db.init(dbPath: '${directory.path}/planner.db');
    addTearDown(db.close);
    final search = ItemSearchController(db);
    addTearDown(search.dispose);
    await NoteProvider(db).addNote(title: 'Prima ricerca');
    await TodoProvider(db).addTodo(title: 'Ultima ricerca');

    search.setQuery('prima');
    final first = search.refresh();
    search.setQuery('ultima');
    await search.refresh();
    await first;
    expect(search.results.single.title, 'Ultima ricerca');
    expect(search.failed, isFalse);
    expect(search.loading, isFalse);
  });
}
