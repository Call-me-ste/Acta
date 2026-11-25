import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_service.dart';
import 'domain/note.dart';
import 'domain/note_folder.dart';
import 'domain/note_link.dart';

part 'note_provider_cache.dart';

/// Stato delle note, con scrittura + outbox e clock di sync.
class NoteProvider extends ChangeNotifier {
  NoteProvider(this._db) {
    reload();
  }
  final DatabaseService _db;
  static const _uuid = Uuid();
  static const String _entity = 'note';
  List<Note> _notes = [];
  List<NoteFolder> _folders = [];

  List<Note> get notes => _notes;
  List<NoteFolder> get folders => _folders;

  void reload() {
    _loadNotes(notifica: false);
    _loadFolders();
  }

  void _loadFolders() {
    _folders = _db.notes.allFolders().map(NoteFolder.fromRow).toList();
    notifyListeners();
  }

  void _loadNotes({bool notifica = true}) {
    _notes = _db.notes.all().map(Note.fromRow).toList()..sort(_compareNotes);
    if (notifica) notifyListeners();
  }
  void _refreshNote(String id) {
    final row = _db.notes.byId(id);
    _notes = _withNote(_notes, id, row == null ? null : Note.fromRow(row));
    notifyListeners();
  }

  Future<Note> addNote({
    String title = '',
    String content = '',
    String? folderId,
  }) async {
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      folderId: folderId,
      updatedAt: DateTime.now(),
    );

    _write(
      () => _db.notes.insert(note.toParams()),
      id: note.id,
      version: note.version,
      updatedAt: note.updatedAt!,
      payload: note.toParams(),
    );
    _refreshNote(note.id);
    return note;
  }

  Future<NoteFolder> addFolder({
    required String name,
    int colorIndex = 0,
    bool pinned = false,
  }) async {
    final now = DateTime.now();
    final folder = NoteFolder(
      id: _uuid.v4(),
      name: name.trim(),
      colorIndex: colorIndex,
      pinned: pinned,
      sortOrder: _folders.length,
      createdAt: now,
      updatedAt: now,
    );
    _db.runInTransaction(() {
      _db.notes.insertFolder(folder.toParams());
      _db.outbox.enqueue(
        operationId: _uuid.v4(),
        entity: 'note_folder',
        entityId: folder.id,
        operation: 'upsert',
        version: folder.version,
        updatedAt: now.millisecondsSinceEpoch,
        payload: folder.toParams(),
      );
    });
    _loadFolders();
    return folder;
  }

  Future<void> updateFolder(NoteFolder folder) async {
    final next = folder.copyWith(
      name: folder.name.trim(),
      version: folder.version + 1,
      updatedAt: DateTime.now(),
    );
    _db.runInTransaction(() {
      _db.notes.updateFolder(next.toParams());
      _db.outbox.enqueue(
        operationId: _uuid.v4(),
        entity: 'note_folder',
        entityId: next.id,
        operation: 'upsert',
        version: next.version,
        updatedAt: next.updatedAt!.millisecondsSinceEpoch,
        payload: next.toParams(),
      );
    });
    _loadFolders();
  }

  /// Elimina la cartella ma **non** le note: le sposta in "Senza cartella".
  Future<void> deleteFolder(NoteFolder folder) async {
    final now = DateTime.now();
    _db.runInTransaction(() {
      for (final nota in _notes.where((n) => n.folderId == folder.id)) {
        final next = nota.copyWith(
          removeFolder: true,
          version: nota.version + 1,
          updatedAt: now,
        );
        _db.notes.update(next.toParams());
        _db.outbox.enqueue(
          operationId: _uuid.v4(),
          entity: _entity,
          entityId: next.id,
          operation: 'upsert',
          version: next.version,
          updatedAt: now.millisecondsSinceEpoch,
          payload: next.toParams(),
        );
      }
      _db.notes.deleteFolder(folder.id);
      _db.outbox.enqueue(
        operationId: _uuid.v4(),
        entity: 'note_folder',
        entityId: folder.id,
        operation: 'delete',
        version: folder.version + 1,
        updatedAt: now.millisecondsSinceEpoch,
        payload: const {},
      );
    });
    _loadNotes();
    _loadFolders();
  }

  Future<void> moveNote(Note note, String? folderId) {
    return updateNote(
      folderId == null
          ? note.copyWith(removeFolder: true)
          : note.copyWith(folderId: folderId),
    );
  }

  Future<void> updateNote(Note note) async {
    final next = note.copyWith(
      version: note.version + 1,
      updatedAt: DateTime.now(),
    );

    _write(
      () => _db.notes.update(next.toParams()),
      id: next.id,
      version: next.version,
      updatedAt: next.updatedAt!,
      payload: next.toParams(),
    );
    _refreshNote(next.id);
  }

  Future<void> togglePinned(Note note) =>
      updateNote(note.copyWith(pinned: !note.pinned));

  Future<void> setPinnedMany(Iterable<String> ids, bool pinned) async {
    for (final id in ids) {
      final nota = byId(id);
      if (nota != null && nota.pinned != pinned) {
        await updateNote(nota.copyWith(pinned: pinned));
      }
    }
  }

  Future<void> deleteNote(String id) async {
    final clock = _db.entities.localClock(_entity, id);
    final now = DateTime.now();

    _write(
      () => _db.notes.delete(id),
      id: id,
      version: (clock?.$1 ?? 0) + 1,
      updatedAt: now,
      payload: null,
    );
    _refreshNote(id);
  }

  /// Cerca per titolo e contenuto nello stesso store delle note.
  List<Note> search(String query) {
    if (query.trim().isEmpty) return _notes;
    return _db.notes.search(query).map(Note.fromRow).toList();
  }

  List<NoteLink> linksOfNote(String noteId) =>
      _db.notes.linksOfNote(noteId).map(NoteLink.fromRow).toList();

  List<NoteLink> linksOfEntity(String entityType, String entityId) => _db.notes
      .linksOfEntity(entityType, entityId)
      .map(NoteLink.fromRow)
      .toList();

  Future<void> linkNote({
    required String noteId,
    required String entityType,
    required String entityId,
  }) async {
    final id = NoteLink.idFor(noteId, entityType, entityId);
    if (_db.notes.linkById(id) != null) return;

    final now = DateTime.now();
    final link = NoteLink(
      id: id,
      noteId: noteId,
      entityType: entityType,
      entityId: entityId,
      createdAt: now,
      updatedAt: now,
    );
    _db.runInTransaction(() {
      _db.notes.insertLink(link.toParams());
      _db.outbox.enqueue(
        operationId: _uuid.v4(),
        entity: 'note_link',
        entityId: id,
        operation: 'upsert',
        version: link.version,
        updatedAt: now.millisecondsSinceEpoch,
        payload: link.toParams(),
      );
    });
    notifyListeners();
  }

  Future<void> unlinkNote(String linkId) async {
    final row = _db.notes.linkById(linkId);
    if (row == null) return;
    final version = (row['version'] as int? ?? 1) + 1;
    final now = DateTime.now();
    _db.runInTransaction(() {
      _db.notes.deleteLink(linkId);
      _db.outbox.enqueue(
        operationId: _uuid.v4(),
        entity: 'note_link',
        entityId: linkId,
        operation: 'delete',
        version: version,
        updatedAt: now.millisecondsSinceEpoch,
        payload: const {},
      );
    });
    notifyListeners();
  }

  Note? byId(String id) {
    for (final note in _notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  void _write(
    void Function() apply, {
    required String id,
    required int version,
    required DateTime updatedAt,
    required Map<String, Object?>? payload,
  }) {
    _db.runInTransaction(() {
      apply();
      _db.outbox.enqueue(
        operationId: _uuid.v4(),
        entity: _entity,
        entityId: id,
        operation: payload == null ? 'delete' : 'upsert',
        version: version,
        updatedAt: updatedAt.millisecondsSinceEpoch,
        payload: payload ?? const {},
      );
    });
  }
}
