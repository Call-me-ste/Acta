import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/notes/note_provider.dart';

void main() {
  late DatabaseService db;
  late NoteProvider provider;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    provider = NoteProvider(db);
  });

  tearDown(() => db.close());

  test('addNote restituisce la nota creata, con id uuid', () async {
    final note = await provider.addNote(title: 'Spesa', content: 'latte');

    expect(note.id, isNotEmpty);
    expect(provider.notes.single.id, note.id);
    expect(provider.notes.single.title, 'Spesa');
  });

  test('updateNote persiste: una nuova istanza sullo stesso DB la rilegge',
      () async {
    final note = await provider.addNote(title: 'Vecchio', content: 'testo');

    await provider.updateNote(
      note.copyWith(title: 'Nuovo', content: 'contenuto nuovo'),
    );

    final fresh = NoteProvider(db);
    expect(fresh.byId(note.id)!.title, 'Nuovo');
    expect(fresh.byId(note.id)!.content, 'contenuto nuovo');
  });

  test('search filtra su titolo e contenuto; query vuota restituisce tutto',
      () async {
    await provider.addNote(title: 'Spesa', content: 'latte e pane');
    await provider.addNote(title: 'Idee', content: 'app planner');

    expect(provider.search('latte').single.title, 'Spesa');
    expect(provider.search('Idee').single.title, 'Idee');
    expect(provider.search('inesistente'), isEmpty);
    expect(provider.search('   '), hasLength(2));
  });

  test('cartelle: crea, sposta e elimina senza perdere note', () async {
    final folder = await provider.addFolder(name: 'Lavoro', colorIndex: 3);
    final note = await provider.addNote(title: 'Riunione', folderId: folder.id);

    expect(provider.folders.single.name, 'Lavoro');
    expect(provider.byId(note.id)!.folderId, folder.id);

    await provider.moveNote(provider.byId(note.id)!, null);
    expect(provider.byId(note.id)!.folderId, isNull);

    await provider.moveNote(provider.byId(note.id)!, folder.id);
    await provider.deleteFolder(provider.folders.single);

    expect(provider.folders, isEmpty);
    expect(provider.byId(note.id), isNotNull);
    expect(provider.byId(note.id)!.folderId, isNull);
  });

  test('il pin della cartella persiste e si rilegge dal database', () async {
    final folder = await provider.addFolder(name: 'Lavoro');

    await provider.updateFolder(folder.copyWith(pinned: true));
    expect(NoteProvider(db).folders.single.pinned, isTrue);

    await provider.updateFolder(folder.copyWith(pinned: false));
    expect(NoteProvider(db).folders.single.pinned, isFalse);
  });

  test('link e unlink persistono e sono bidirezionali', () async {
    final note = await provider.addNote(title: 'Preparare', content: 'valigia');

    await provider.linkNote(
      noteId: note.id,
      entityType: 'event',
      entityId: 'evento-1',
    );
    await provider.linkNote(
      noteId: note.id,
      entityType: 'todo',
      entityId: 'todo-1',
    );

    expect(provider.linksOfNote(note.id), hasLength(2));
    expect(provider.linksOfEntity('event', 'evento-1').single.noteId, note.id);
    expect(provider.linksOfEntity('todo', 'todo-1').single.noteId, note.id);

    final fresh = NoteProvider(db);
    expect(fresh.linksOfNote(note.id), hasLength(2));

    final link = provider.linksOfNote(note.id).first;
    await provider.unlinkNote(link.id);
    expect(provider.linksOfNote(note.id), hasLength(1));
  });

  test('deleteNote rimuove la nota', () async {
    final note = await provider.addNote(title: 'usa e getta');

    await provider.deleteNote(note.id);

    expect(provider.notes, isEmpty);
    expect(provider.byId(note.id), isNull);
  });
}

