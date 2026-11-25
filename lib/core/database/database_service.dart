import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../app_version.dart';
import 'category_store.dart';
import 'database_metadata.dart';
import 'entity_store.dart';
import 'note_store.dart';
import 'occurrence_store.dart';
import 'outbox_store.dart';
import 'palette_store.dart';
import 'place_store.dart';
import 'schema.dart';
import 'settings_store.dart';

class DatabaseService {
  late final Database _db;
  bool _isOpen = false;
  // NON `final`: si scrive in `init`, e un ripristino la rilegge (il percorso
  // non cambia, ma il compilatore non lo sa).
  String _dbPath = '';

  /// Il percorso del file su disco.
  ///
  /// Serve a chi lavora **sui file** — copie, dimensioni, ripristino: vedi
  /// `database_files.dart`. Il resto del codice legge e scrive righe, e del
  /// percorso non deve sapere niente.
  String get path => _dbPath;

  /// La versione dello schema **prima** che questa apertura lo toccasse.
  ///
  /// Serve a sapere se l'apertura ha portato il database a una versione nuova
  /// (e quindi se prima si e' dovuta fare una copia) e a dirlo in Impostazioni.
  int _schemaVersionAtOpen = 0;

  int get schemaVersionAtOpen => _schemaVersionAtOpen;

  /// La versione dello schema adesso (dopo `applySchema`).
  int get currentSchemaVersion => readSchemaVersion(_db);

  /// Apre il database.
  ///
  /// [primaDiMigrare] si chiama **solo** quando questa apertura sta per portare
  /// uno schema esistente a una versione nuova, e si chiama **prima** che lo
  /// schema venga toccato: e' il gancio con cui si fa la copia di sicurezza di
  /// un aggiornamento dell'app. Un percorso nuovo (nessuno schema dentro) non lo
  /// fa scattare: non c'e' niente da perdere.
  Future<void> init({
    String? dbPath,
    Future<void> Function(int daVersione)? primaDiMigrare,
    Future<bool> Function(int daVersione, String? daAppVersion)?
        primaDiAggiornare,
    String? appVersion,
  }) async {
    if (_isOpen) return;

    // dbPath exists for tests (`:memory:`); production keeps the app documents dir.
    final path = dbPath ??
        p.join((await getApplicationDocumentsDirectory()).path, 'planner.db');

    _dbPath = path;
    _db = sqlite3.open(path);
    // WAL lascia leggere mentre si salva. Il timeout copre lock brevi.
    _db.execute('PRAGMA busy_timeout = 5000');
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA synchronous = NORMAL');
    _db.execute('PRAGMA cache_size = -8000');
    // Letta **prima** di applicare lo schema: `applySchema` scrive la versione
    // nuova, e dopo non si saprebbe piu' da dove si veniva.
    _schemaVersionAtOpen = readSchemaVersion(_db);
    if (_schemaVersionAtOpen > schemaVersion) {
      _db.dispose();
      throw StateError(
        'Il database è stato creato da una versione più nuova del Planner '
        '(schema $_schemaVersionAtOpen, questa build conosce $schemaVersion). '
        'Aggiorna l\'app: aprire un file più nuovo con un codice vecchio può '
        'perdere dati.',
      );
    }

    // Un aggiornamento va riconosciuto **prima** di applicare lo schema. La
    // versione sta in `app_settings`, che esiste già in ogni database con dati.
    final esistente = hasExistingSchema(_db);
    final daAppVersion = esistente ? readAppVersion(_db) : null;
    final versioneCambiata =
        appVersion != null && esistente && daAppVersion != appVersion;
    final deveMigrare = needsMigration(_db);
    var copiaRiuscita = true;
    try {
      if (deveMigrare || versioneCambiata) {
        if (primaDiAggiornare != null) {
          copiaRiuscita =
              await primaDiAggiornare(_schemaVersionAtOpen, daAppVersion);
        } else if (needsMigration(_db)) {
          await primaDiMigrare?.call(_schemaVersionAtOpen);
        }
      }
      if (deveMigrare && !copiaRiuscita) throw const MigrationBackupRequired();
    } catch (_) {
      _db.dispose();
      rethrow;
    }
    applySchema(_db);
    if (appVersion != null && copiaRiuscita) {
      settings.set(AppVersion.settingsKey, appVersion);
    }
    _isOpen = true;
  }

  void close() {
    if (!_isOpen) return;
    _db.dispose();
    _isOpen = false;
  }

  Database get instance => _db;

  /// Le tre viste SQL che stanno fuori da questo file: l'outbox, lo stato del
  /// sync e l'accesso generico alle entità. Sono `late` perché `_db` esiste
  /// solo dopo `init()`.
  late final OutboxStore outbox = OutboxStore(_db);
  late final MetaStore meta = MetaStore(_db);
  late final EntityStore entities = EntityStore(_db);
  late final OccurrenceStore occurrences = OccurrenceStore(_db);
  late final SettingsStore settings = SettingsStore(_db);
  late final PaletteStore palettes = PaletteStore(_db);
  late final PlaceStore places = PlaceStore(_db);
  late final NoteStore notes = NoteStore(_db);
  late final CategoryStore categories = CategoryStore(_db);

  /// Esegue `action` in una transazione: o passa tutto, o non passa niente.
  ///
  /// Serve a tenere insieme "scrivo il dato" e "accodo l'operazione di sync":
  /// senza transazione un errore del secondo lascerebbe il primo scritto, e la
  /// modifica non partirebbe mai.
  void runInTransaction(void Function() action) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      action();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  // ─── Events CRUD ──────────────────────────────────────

  List<Row> getEvents() {
    return _db.select('SELECT * FROM events ORDER BY start_time DESC');
  }

  /// Gli eventi concreti che iniziano nella finestra.
  ///
  /// I ricorrenti si escludono **qui**: le loro occorrenze le genera
  /// l'espansione, e tenerli anche come righe sarebbe il modo per farli
  /// comparire due volte nella stessa vista.
  List<Row> getEventsBetween(DateTime from, DateTime to) {
    return _db.select(
      'SELECT * FROM events WHERE start_time >= ? AND start_time < ? '
      'AND COALESCE(recurrence_rule, \'\') = \'\' ORDER BY start_time',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
  }

  List<Row> getRecurringEvents() {
    return _db.select(
      'SELECT * FROM events WHERE COALESCE(recurrence_rule, \'\') != \'\' '
      'ORDER BY start_time',
    );
  }

  void insertEvent(Map<String, dynamic> event) {
    // `updated_at` esplicito quando c'è: così la riga e la voce in outbox
    // portano lo **stesso** clock, invece di differire di qualche millisecondo.
    _db.execute(
      '''INSERT INTO events (id, title, description, start_time, end_time, all_day, color_index, color_hex, recurrence_rule, reminder_leads, reminder_sound, location, note, category_ids, version, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        event['id'],
        event['title'],
        event['description'] ?? '',
        event['start_time'],
        event['end_time'],
        event['all_day'] ?? 0,
        event['color_index'] ?? 0,
        event['color_hex'],
        event['recurrence_rule'] ?? '',
        event['reminder_leads'],
        event['reminder_sound'],
        event['location'] ?? '',
        event['note'] ?? '',
        event['category_ids'] ?? '',
        event['version'] ?? 1,
        event['updated_at'] ?? DateTime.now().millisecondsSinceEpoch
      ],
    );
  }

  void updateEvent(Map<String, dynamic> event) {
    // `version` e `updated_at` si aggiornano insieme: sono il clock con cui il
    // sync decide chi vince fra due dispositivi.
    _db.execute(
      '''UPDATE events SET title=?, description=?, start_time=?, end_time=?, all_day=?, color_index=?, color_hex=?, recurrence_rule=?, reminder_leads=?, reminder_sound=?, location=?, note=?, category_ids=?, version=?, updated_at=? WHERE id=?''',
      [
        event['title'],
        event['description'] ?? '',
        event['start_time'],
        event['end_time'],
        event['all_day'] ?? 0,
        event['color_index'] ?? 0,
        event['color_hex'],
        event['recurrence_rule'] ?? '',
        event['reminder_leads'],
        event['reminder_sound'],
        event['location'] ?? '',
        event['note'] ?? '',
        event['category_ids'] ?? '',
        event['version'] ?? 1,
        event['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
        event['id']
      ],
    );
  }

  void deleteEvent(String id) {
    _db.execute('DELETE FROM events WHERE id = ?', [id]);
  }

  // ─── Todos CRUD ──────────────────────────────────────

  List<Row> getTodos() {
    // updated_at, not created_at: the todos table never had a created_at column,
    // so the previous ORDER BY threw `no such column` on every call.
    return _db
        .select('SELECT * FROM todos ORDER BY priority DESC, updated_at ASC');
  }

  void insertTodo(Map<String, dynamic> todo) {
    _db.execute(
      '''INSERT INTO todos (id, title, completed, priority, due_date, start_time, end_time, hidden_in_calendar, category_ids, color_index, recurrence_rule, reminder_leads, reminder_sound, location, note, version, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        todo['id'],
        todo['title'],
        todo['completed'] ?? 0,
        todo['priority'] ?? 0,
        todo['due_date'],
        todo['start_time'],
        todo['end_time'],
        todo['hidden_in_calendar'] ?? 0,
        todo['category_ids'] ?? '',
        todo['color_index'],
        todo['recurrence_rule'] ?? '',
        todo['reminder_leads'],
        todo['reminder_sound'],
        todo['location'] ?? '',
        todo['note'] ?? '',
        todo['version'] ?? 1,
        todo['updated_at'] ?? DateTime.now().millisecondsSinceEpoch
      ],
    );
  }

  void updateTodo(Map<String, dynamic> todo) {
    _db.execute(
      '''UPDATE todos SET title=?, completed=?, priority=?, due_date=?, start_time=?, end_time=?, hidden_in_calendar=?, category_ids=?, color_index=?, recurrence_rule=?, reminder_leads=?, reminder_sound=?, location=?, note=?, version=?, updated_at=? WHERE id=?''',
      [
        todo['title'],
        todo['completed'] ?? 0,
        todo['priority'] ?? 0,
        todo['due_date'],
        todo['start_time'],
        todo['end_time'],
        todo['hidden_in_calendar'] ?? 0,
        todo['category_ids'] ?? '',
        todo['color_index'],
        todo['recurrence_rule'] ?? '',
        todo['reminder_leads'],
        todo['reminder_sound'],
        todo['location'] ?? '',
        todo['note'] ?? '',
        todo['version'] ?? 1,
        todo['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
        todo['id']
      ],
    );
  }

  void deleteTodo(String id) {
    _db.execute('DELETE FROM todos WHERE id = ?', [id]);
  }
}

class MigrationBackupRequired implements Exception {
  const MigrationBackupRequired();
}
