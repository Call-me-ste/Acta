import 'package:sqlite3/sqlite3.dart';

/// Accesso generico alle tabelle delle entità, per il sync.
///
/// Qui il nome di tabella e l'elenco delle colonne **non arrivano mai**
/// dall'esterno: un record può venire da uno shard remoto, quindi i suoi campi
/// sono dati non fidati e finirebbero interpolati in SQL. Si passa da questa
/// mappa e nient'altro.
class EntityStore {
  EntityStore(this._db);

  final Database _db;

  static const Map<String, String> _tables = {
    'event': 'events',
    'todo': 'todos',
    'note': 'notes',
    'note_link': 'note_links',
    'note_folder': 'note_folders',
    'occurrence_override': 'occurrence_overrides',
    'palette': 'palettes',
    'category': 'categories',
  };

  static const Map<String, Set<String>> _columns = {
    'event': {
      'id',
      'title',
      'description',
      'start_time',
      'end_time',
      'all_day',
      'color_index',
      'color_hex',
      'recurrence_rule',
      'reminder_leads',
      'reminder_sound',
      'location',
      'note',
      'category_ids',
      'version',
      'updated_at',
    },
    'todo': {
      'id',
      'title',
      'completed',
      'priority',
      'due_date',
      'start_time',
      'end_time',
      'hidden_in_calendar',
      'category',
      'color_index',
      'recurrence_rule',
      'reminder_leads',
      'reminder_sound',
      'location',
      'note',
      'category_ids',
      'version',
      'updated_at',
    },
    'note': {
      'id',
      'title',
      'content',
      'pinned',
      'folder_id',
      'version',
      'created_at',
      'updated_at',
    },
    'note_link': {
      'id',
      'note_id',
      'entity_type',
      'entity_id',
      'version',
      'created_at',
      'updated_at',
    },
    'note_folder': {
      'id',
      'name',
      'color_index',
      'sort_order',
      'pinned',
      'version',
      'created_at',
      'updated_at',
    },
    'occurrence_override': {
      'id',
      'item_id',
      'occurrence_date',
      'state',
      'version',
      'updated_at',
    },
    'palette': {
      'id',
      'name',
      'seed_hex',
      'colors_json',
      'is_preset',
      'version',
      'updated_at',
    },
    'category': {
      'id',
      'name',
      'emoji',
      'color_hex',
      'version',
      'updated_at',
    },
  };

  static bool isKnown(String entity) => _tables.containsKey(entity);

  static Iterable<String> get kinds => _tables.keys;

  /// Le colonne che un record può portare per quell'entità. Serve anche
  /// all'export, che deve sapere cosa copiare da una riga letta dal database.
  static Set<String> columnsFor(String entity) => _columns[entity] ?? const {};

  List<Row> allRows(String entity) {
    return _db.select('SELECT * FROM ${_requireTable(entity)}');
  }

  Row? rowById(String entity, String id) => _db.select(
        'SELECT * FROM ${_requireTable(entity)} WHERE id = ?',
        [id],
      ).firstOrNull;

  List<Row> rowsWithoutOutbox(String entity) => _db.select(
        'SELECT item.* FROM ${_requireTable(entity)} AS item '
        'WHERE NOT EXISTS (SELECT 1 FROM outbox '
        'WHERE entity_type = ? AND entity_id = item.id)',
        [entity],
      );

  /// Il clock locale di un'entità: `(version, updated_at)`. `null` se la riga
  /// non esiste (o è stata cancellata). È il termine di paragone dei conflitti.
  (int version, int updatedAt)? localClock(String entity, String id) {
    final table = _tables[entity];
    if (table == null) return null;

    final rows = _db.select(
      'SELECT version, updated_at FROM $table WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return (
      (rows.first['version'] as int?) ?? 1,
      (rows.first['updated_at'] as int?) ?? 0,
    );
  }

  bool exists(String entity, String id) => localClock(entity, id) != null;

  /// Scrive la riga così com'è nel record: prima elimina, poi inserisce. Con
  /// un `INSERT OR REPLACE` le colonne che il record non porta resterebbero
  /// quelle vecchie, che è l'opposto di quello che vuole un sync.
  void replace(String entity, String id, Map<String, Object?> data) {
    final table = _requireTable(entity);
    final allowed = _columns[entity]!;

    // Compatibilità in avanti: un record scritto da una versione più nuova può
    // portare colonne che qui non esistono. Si tiene la riga e si perde solo
    // quel campo — l'alternativa era far fallire l'intero sync per un campo che
    // non sappiamo nemmeno leggere. Il filtro resta obbligatorio: i nomi di
    // colonna finiscono in SQL, e questi arrivano dalla rete.
    final columns = data.keys.where(allowed.contains).toList(growable: false);
    if (columns.isEmpty) {
      throw FormatException('Record "$entity" senza nessuna colonna nota');
    }

    _db.execute('DELETE FROM $table WHERE id = ?', [id]);

    final placeholders = List.filled(columns.length, '?').join(', ');
    _db.execute(
      'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)',
      columns.map((column) => data[column]).toList(),
    );
  }

  void remove(String entity, String id) {
    _db.execute('DELETE FROM ${_requireTable(entity)} WHERE id = ?', [id]);
  }

  String _requireTable(String entity) {
    final table = _tables[entity];
    if (table == null) {
      throw FormatException('Entità sconosciuta: "$entity"');
    }
    return table;
  }
}
