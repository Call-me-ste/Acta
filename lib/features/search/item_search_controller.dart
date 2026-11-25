import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/database/database_service.dart';
import '../events/domain/event.dart';
import '../notes/domain/note.dart';
import '../todos/domain/todo.dart';

enum SearchKind {
  event('Evento', 'events'),
  todo('To do', 'todos'),
  note('Nota', 'notes');

  const SearchKind(this.label, this.table);
  final String label;
  final String table;
}

typedef SearchHit = ({
  SearchKind kind,
  String id,
  String title,
  DateTime? date,
});

class ItemSearchController extends ChangeNotifier {
  ItemSearchController(this._database);

  final DatabaseService _database;
  Timer? _debounce;
  int _revision = 0;
  String _query = '';
  List<SearchHit> results = const [];
  bool hasMore = false;
  bool loading = false;
  bool failed = false;
  bool get isEmptyQuery => _query.isEmpty;

  void setQuery(String raw) {
    final query = raw.trim().toLowerCase();
    if (_query == query) return;
    _query = query;
    _revision++;
    _debounce?.cancel();
    results = const [];
    hasMore = false;
    failed = false;
    loading = query.isNotEmpty;
    notifyListeners();
    if (loading) {
      _debounce = Timer(const Duration(milliseconds: 180), refresh);
    }
  }

  Future<void> refresh() async {
    _debounce?.cancel();
    final query = _query;
    if (query.isEmpty) return;
    final revision = ++_revision;
    final path = _database.path;
    try {
      // A production database uses WAL. A read-only worker sees the committed
      // data without running the text scan on Flutter's UI isolate.
      final matches = path == ':memory:'
          ? _findMatches(_database.instance, query)
          : await compute(_searchFile, (path: path, query: query));
      if (revision != _revision) return;
      hasMore = matches.length > 100;
      results = matches.take(100).toList(growable: false);
      failed = false;
    } catch (_) {
      if (revision != _revision) return;
      failed = true;
    }
    loading = false;
    notifyListeners();
  }

  Object? read(SearchHit result) {
    final rows = _database.instance.select(
      'SELECT * FROM ${result.kind.table} WHERE id = ?',
      [result.id],
    );
    if (rows.isEmpty) return null;
    return switch (result.kind) {
      SearchKind.event => Event.fromRow(rows.single),
      SearchKind.todo => Todo.fromRow(rows.single),
      SearchKind.note => Note.fromRow(rows.single),
    };
  }

  @override
  void dispose() {
    _revision++;
    _debounce?.cancel();
    super.dispose();
  }
}

List<SearchHit> _searchFile(({String path, String query}) job) {
  final connection = sqlite3.open(job.path, mode: OpenMode.readOnly);
  try {
    return _findMatches(connection, job.query);
  } finally {
    connection.dispose();
  }
}

List<SearchHit> _findMatches(Database connection, String query) {
  connection.createFunction(
    functionName: 'acta_lower',
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
    function: (args) => (args[0] as String?)?.toLowerCase() ?? '',
  );
  final rows = connection.select('''
    WITH items AS (
      SELECT 'event' AS kind, id, title, start_time AS date, updated_at,
        ifnull(location, '') || char(10) || ifnull(note, '') ||
        char(10) || ifnull(description, '') AS body
        FROM events
      UNION ALL
      SELECT 'todo', id, title, due_date, updated_at,
        ifnull(location, '') || char(10) || ifnull(note, '') FROM todos
      UNION ALL
      SELECT 'note', id, title, NULL, updated_at, content FROM notes
    )
    SELECT kind, id, title, date FROM items
    WHERE instr(acta_lower(title), ?1) > 0 OR instr(acta_lower(body), ?1) > 0
    ORDER BY (instr(acta_lower(title), ?1) > 0) DESC, updated_at DESC, id
    LIMIT 101
  ''', [query]);
  return [
    for (final row in rows)
      (
        kind: SearchKind.values.byName(row['kind'] as String),
        id: row['id'] as String,
        title: (row['title'] as String?) ?? '',
        date: switch (row['date']) {
          final int date => DateTime.fromMillisecondsSinceEpoch(date),
          _ => null,
        },
      ),
  ];
}
