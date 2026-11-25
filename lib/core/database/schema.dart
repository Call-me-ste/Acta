import 'package:sqlite3/sqlite3.dart';

import 'note_folder_schema.dart';
import 'note_attachment_schema.dart';

/// La **versione dello schema** del database.
///
/// Sale a mano quando `_migrate` impara qualcosa di nuovo, e sta **dentro il
/// database** (`PRAGMA user_version`), non in una tabella: serve a decidere cosa
/// fare **prima** di sapere com'e' fatto il file, cioè a distinguere un database
/// nuovo da uno di una versione precedente. Da quella distinzione dipendono due
/// cose: la copia di sicurezza prima di toccare lo schema, e il rifiuto di un
/// backup scritto da una versione **piu' nuova** di questa (aprire un file con
/// colonne che non conosciamo e' il modo di perdere dati in silenzio).
///
/// Regola: si alza quando l'apertura **cambia** un database esistente
/// (una colonna nuova, un indice in meno).
const int schemaVersion = 2;

/// La versione dello schema scritta nel database.
///
/// `0` significa "mai scritta": o è un file appena creato, o è un database nato
/// prima che questa versione esistesse. I due casi si distinguono da quello che
/// c'è **dentro** il file ([hasExistingSchema]), non da un numero.
int readSchemaVersion(Database db) {
  final rows = db.select('PRAGMA user_version');
  return (rows.first['user_version'] as int?) ?? 0;
}

/// Vero se questo database va **portato** a una versione nuova dello schema.
///
/// Serve a decidere se fare una copia **prima** di toccare qualcosa: un file
/// appena creato non ha niente da perdere, un database che esiste si'. I due casi
/// hanno entrambi `user_version = 0` e si distinguono da quello che c'e' dentro
/// il file — non da un numero.
bool needsMigration(Database db) =>
    readSchemaVersion(db) < schemaVersion && hasExistingSchema(db);

/// Vero se il file contiene **gia'** il nostro schema.
///
/// Serve a non confondere due database che hanno entrambi `user_version = 0`:
/// un file nuovo (niente da perdere, nessuna copia da fare) e un database di una
/// versione precedente (dati dentro, e una copia da fare prima di migrare).
bool hasExistingSchema(Database db) {
  final rows = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'events'",
  );
  return rows.isNotEmpty;
}

/// Lo schema del database, in un posto solo.
/// Sta fuori da `DatabaseService` perché quel file ha un budget di 300 righe
/// (test/architecture_test.dart) e perché "com'è fatta la tabella" e "come la si
/// usa" sono due cose diverse.
const List<String> _tables = [
  '''
    CREATE TABLE IF NOT EXISTS events (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT DEFAULT '',
      start_time INTEGER NOT NULL,
      end_time INTEGER NOT NULL,
      all_day INTEGER DEFAULT 0,
      color_index INTEGER DEFAULT 0,
      color_hex TEXT,
      recurrence_rule TEXT DEFAULT '',
      reminder_leads TEXT,
      reminder_sound INTEGER,
      location TEXT DEFAULT '',
      note TEXT DEFAULT '',
      category_ids TEXT DEFAULT '',
      version INTEGER DEFAULT 1,
      updated_at INTEGER DEFAULT (strftime('%s','now') * 1000)
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS todos (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      completed INTEGER DEFAULT 0,
      priority INTEGER DEFAULT 0,
      due_date INTEGER,
      -- Gli **orari** del todo: minuti dalla mezzanotte (0-1439), nullable.
      -- La data resta in `due_date`: cosi' spostare la scadenza non tocca
      -- l'orario, che e' quello che ci si aspetta.
      start_time INTEGER,
      end_time INTEGER,
      -- «Via dal calendario»: il todo resta nella scheda Todo e in Agenda, ma
      -- le griglie (mese, settimana, giorno) non lo mostrano piu'. E' il segno
      -- che mette lo scorrimento a destra su un todo del calendario.
      hidden_in_calendar INTEGER DEFAULT 0,
      category TEXT DEFAULT '',
      color_index INTEGER,
      recurrence_rule TEXT DEFAULT '',
      reminder_leads TEXT,
      reminder_sound INTEGER,
      location TEXT DEFAULT '',
      note TEXT DEFAULT '',
      category_ids TEXT DEFAULT '',
      version INTEGER DEFAULT 1,
      updated_at INTEGER DEFAULT (strftime('%s','now') * 1000)
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS notes (
      id TEXT PRIMARY KEY,
      title TEXT DEFAULT '',
      content TEXT DEFAULT '',
      pinned INTEGER DEFAULT 0,
      version INTEGER DEFAULT 1,
      created_at INTEGER DEFAULT (strftime('%s','now') * 1000),
      updated_at INTEGER DEFAULT (strftime('%s','now') * 1000)
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS note_links (
      id TEXT PRIMARY KEY,
      note_id TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      version INTEGER DEFAULT 1,
      created_at INTEGER DEFAULT (strftime('%s','now') * 1000),
      updated_at INTEGER DEFAULT (strftime('%s','now') * 1000),
      UNIQUE (note_id, entity_type, entity_id)
    )
  ''',
  '''
    CREATE INDEX IF NOT EXISTS idx_note_links_entity
      ON note_links (entity_type, entity_id)
  ''',
  '''
    CREATE TABLE IF NOT EXISTS outbox (
      operation_id TEXT PRIMARY KEY,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      entity_version INTEGER DEFAULT 0,
      entity_updated_at INTEGER DEFAULT 0,
      sync_state TEXT DEFAULT 'pending',
      retry_count INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT (strftime('%s','now') * 1000)
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS sync_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''',
  // Preferenze di QUESTO device: tema scelto, palette attiva, animazioni,
  // cartella di backup. Non è una famiglia di sync di proposito: il telefono e
  // il PC possono volere temi e cartelle diversi, e l'outbox non c'entra nulla
  // con una preferenza locale.
  '''
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''',
  // La LIBRERIA delle palette, invece, viaggia: `colors_json` è la lista degli
  // hex, il seed genera il tema (chiaro e scuro). `is_preset = 1` significa
  // "read-only": per personalizzarla si duplica, così un preset non può essere
  // rotto per sbaglio e i due device restano d'accordo su cosa sia un preset.
  '''
    CREATE TABLE IF NOT EXISTS palettes (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      seed_hex TEXT NOT NULL,
      colors_json TEXT NOT NULL,
      simple_json TEXT,
      is_preset INTEGER DEFAULT 0,
      version INTEGER DEFAULT 1,
      updated_at INTEGER DEFAULT (strftime('%s','now') * 1000)
    )
  ''',
  // Una riga per "questa occorrenza di questa serie è fatta (o saltata)".
  // L'`id` è `itemId@yyyy-MM-dd`: così la tabella entra nel sync generico come
  // tutte le altre entità, senza un percorso SQL dedicato.
  // Le categorie: la libreria che viaggia fra i device, come le palette.
  // L'assegnazione a un evento o a un todo sta invece nella colonna
  // `category_ids` dell'elemento (massimo 3, vedi core/categories/category_ids).
  '''
    CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      emoji TEXT DEFAULT '',
      color_hex TEXT DEFAULT '',
      version INTEGER DEFAULT 1,
      updated_at INTEGER DEFAULT (strftime('%s','now') * 1000)
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS occurrence_overrides (
      id TEXT PRIMARY KEY,
      item_id TEXT NOT NULL,
      occurrence_date INTEGER NOT NULL,
      state TEXT NOT NULL,
      version INTEGER DEFAULT 1,
      updated_at INTEGER DEFAULT (strftime('%s','now') * 1000)
    )
  ''',
];

const List<String> _indexes = [
  'CREATE INDEX IF NOT EXISTS idx_events_start_time ON events(start_time)',
  'CREATE INDEX IF NOT EXISTS idx_todos_completed ON todos(completed)',
  // La griglia del mese e la scheda Todo chiedono i todo di una finestra di
  // giorni: senza questo indice ogni finestra è una scansione intera.
  'CREATE INDEX IF NOT EXISTS idx_todos_due_date ON todos(due_date)',
  'CREATE INDEX IF NOT EXISTS idx_outbox_sync_state ON outbox(sync_state)',
  'CREATE INDEX IF NOT EXISTS idx_outbox_entity ON outbox(entity_type, entity_id)',
  // Composito: copre sia «le conferme di questo elemento» sia «quella
  // occorrenza», che è la coppia che si interroga davvero (`isDone`).
  'CREATE INDEX IF NOT EXISTS idx_occurrence_item_day ON occurrence_overrides(item_id, occurrence_date)',
];

void applySchema(Database db) {
  for (final statement in _tables) {
    db.execute(statement);
  }
  for (final statement in _indexes) {
    db.execute(statement);
  }
  _migrate(db);
  applyNoteAttachmentSchema(db);
  _dropObsoleteIndexes(db);
  // La versione si scrive **dopo** aver applicato tutto: se una migrazione
  // fallisse a metà, il numero resterebbe quello di prima e il prossimo avvio
  // riproverebbe (le migrazioni sono additive e idempotenti, quindi riprovare
  // e' sicuro). `user_version` non accetta parametri: il valore e' una costante
  // del codice, non un dato che arriva da fuori.
  db.execute('PRAGMA user_version = $schemaVersion');
}

/// Indici obsoleti: toglierli è idempotente.
void _dropObsoleteIndexes(Database db) {
  db.execute('DROP INDEX IF EXISTS idx_occurrence_item');
}

/// Migrazioni additive, idempotenti, a ogni avvio.
void _migrate(Database db) {
  ensureNoteFolders(db);
  _ensureColumn(db, 'outbox', 'entity_version', 'INTEGER DEFAULT 0');
  _ensureColumn(db, 'outbox', 'entity_updated_at', 'INTEGER DEFAULT 0');
  _ensureColumn(db, 'notes', 'version', 'INTEGER DEFAULT 1');
  _ensureColumn(db, 'todos', 'recurrence_rule', "TEXT DEFAULT ''");
  // Fase 1 — colore: `color_hex` è la scelta libera di un singolo evento e
  // vince su `color_index` (che resta l'indice nella palette attiva);
  // `color_index` sul todo serve ai puntini del mese.
  _ensureColumn(db, 'events', 'color_hex', 'TEXT');
  _ensureColumn(db, 'todos', 'color_index', 'INTEGER');
  // Punto D — promemoria, posizione e nota, sulle due tabelle che il form
  // unico riempie. `reminder_leads` è testo (`"15,60"`, vedi
  // core/reminders/reminder_leads.dart), `reminder_sound` è a tre stati
  // (`NULL` = eredita, 0/1 = spento/acceso).
  for (final table in ['events', 'todos']) {
    _ensureColumn(db, table, 'reminder_leads', 'TEXT');
    _ensureColumn(db, table, 'reminder_sound', 'INTEGER');
    _ensureColumn(db, table, 'location', "TEXT DEFAULT ''");
    _ensureColumn(db, table, 'note', "TEXT DEFAULT ''");
  }
  // Fase 2 — i quattro colori del modo **semplice** (fondo, superfici, testo,
  // accento), come mappa ruolo → hex. Vuoto o assente = il tema lo genera il
  // seed, che e' come si comportava prima di questa colonna.
  _ensureColumn(db, 'palettes', 'simple_json', 'TEXT');
  _ensureColumn(db, 'notes', 'pinned', 'INTEGER DEFAULT 0');
  // Fase A1 — categorie: gli id delle categorie di un elemento (`"id1,id2"`,
  // massimo 3). La vecchia colonna `category` dei todo resta in tabella perche'
  // la conversione la legge una volta sola, poi si svuota (vedi
  // CategoryController.migrateLegacyCategoryColumn).
  for (final table in ['events', 'todos']) {
    _ensureColumn(db, table, 'category_ids', "TEXT DEFAULT ''");
  }
  // Orari dei todo: minuti dalla mezzanotte, nullable (un todo puo' avere solo
  // data, solo inizio, solo fine o entrambi). Non sono timestamp come quelli
  // degli eventi apposta: la data sta in `due_date`, e cosi' spostare la
  // scadenza non lascia l'orario legato a un giorno che non c'e' piu'.
  _ensureColumn(db, 'todos', 'start_time', 'INTEGER');
  _ensureColumn(db, 'todos', 'end_time', 'INTEGER');
  // «Via dal calendario»: 0 = si vede (il default di chi aggiorna), quindi le
  // righe che c'erano restano tutte visibili.
  _ensureColumn(db, 'todos', 'hidden_in_calendar', 'INTEGER DEFAULT 0');
}

void _ensureColumn(
  Database db,
  String table,
  String column,
  String declaration,
) {
  final present = db
      .select('PRAGMA table_info($table)')
      .any((row) => row['name'] == column);
  if (!present) {
    db.execute('ALTER TABLE $table ADD COLUMN $column $declaration');
  }
}
