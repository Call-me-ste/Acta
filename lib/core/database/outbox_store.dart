import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// L'outbox: le operazioni in attesa di partire, e il cursore del sync.
///
/// Vive fuori da `DatabaseService` perché quel file ha un budget di 300 righe
/// (test/architecture_test.dart) e perché qui c'è **solo** SQL di pertinenza del
/// sync: il codice che lo usa non deve sapere come è fatta la tabella.
class OutboxStore {
  OutboxStore(this._db);

  final Database _db;

  // L'ordine e' quello di **inserimento** (`rowid`), non `created_at`: la
  // colonna nasce da `strftime('%s','now') * 1000`, cioe' ha la risoluzione del
  // **secondo**, e cinque scritture nello stesso secondo hanno tutte la stessa
  // data. Ordinare per una data uguale vuol dire ordinare a caso — e su questa
  // coda "a caso" vuol dire poter spedire lo stato vecchio di un elemento al
  // posto di quello nuovo. Il bug l'ha trovato il test della compattazione.
  static const String _pendingQuery =
      "SELECT * FROM outbox WHERE sync_state != 'synced' ORDER BY rowid ASC";

  List<Row> pending() => _db.select(_pendingQuery);

  int pendingCount() {
    final rows = _db.select(
      "SELECT COUNT(*) AS total FROM outbox WHERE sync_state != 'synced'",
    );
    return rows.first['total'] as int;
  }

  /// Accoda un'operazione. `version` e `updatedAt` si fotografano **adesso**:
  /// leggerli al momento del push darebbe il valore sbagliato se nel frattempo
  /// l'entità è cambiata di nuovo.
  void enqueue({
    required String operationId,
    required String entity,
    required String entityId,
    required String operation,
    required int version,
    required int updatedAt,
    required Map<String, Object?> payload,
  }) {
    _db.execute(
      '''INSERT INTO outbox
           (operation_id, entity_type, entity_id, operation, payload_json,
            entity_version, entity_updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [
        operationId,
        entity,
        entityId,
        operation,
        jsonEncode(payload),
        version,
        updatedAt,
      ],
    );
  }

  /// Il clock dell'operazione ancora in coda per quell'entità, se esiste.
  ///
  /// L'ultima riga è quella inserita per ultima (`rowid`, vedi [_pendingQuery]):
  /// con `created_at` — che ha la risoluzione del secondo — due scritture vicine
  /// potevano invertirsi, e il clock che il sync legge sarebbe stato quello
  /// **vecchio**.
  (int version, int updatedAt)? pendingClock(String entity, String entityId) {
    final rows = _db.select(
      '''SELECT entity_version, entity_updated_at FROM outbox
         WHERE entity_type = ? AND entity_id = ? AND sync_state != 'synced'
         ORDER BY rowid DESC LIMIT 1''',
      [entity, entityId],
    );
    if (rows.isEmpty) return null;
    return (
      (rows.first['entity_version'] as int?) ?? 0,
      (rows.first['entity_updated_at'] as int?) ?? 0,
    );
  }

  void markSynced(List<String> operationIds) {
    for (final operationId in operationIds) {
      _db.execute(
        "UPDATE outbox SET sync_state = 'synced' WHERE operation_id = ?",
        [operationId],
      );
    }
  }

  void markFailed(String operationId) {
    _db.execute(
      '''UPDATE outbox
         SET retry_count = retry_count + 1,
             sync_state = CASE WHEN retry_count + 1 >= 3 THEN 'failed' ELSE 'pending' END
         WHERE operation_id = ?''',
      [operationId],
    );
  }

  /// Quante righe toglierebbe una compattazione, **senza** farla.
  ///
  /// Serve a decidere se vale la pena: compattare una coda gia' compatta vuol dire
  /// riscrivere il database per niente. Una riga per elemento resta sempre, quindi
  /// il conto e' «righe in coda meno elementi distinti».
  int compactableCount() {
    final righe = _db
        .select(
          "SELECT COUNT(*) AS n FROM outbox WHERE sync_state != 'synced'",
        )
        .first['n'] as int;
    final elementi = _db
        .select(
          'SELECT COUNT(*) AS n FROM (SELECT 1 FROM outbox '
          "WHERE sync_state != 'synced' GROUP BY entity_type, entity_id)",
        )
        .first['n'] as int;
    return righe - elementi;
  }

  /// Compatta la coda: per ogni elemento resta **solo** l'operazione non
  /// sincronizzata piu' recente, e le righe gia' sincronizzate piu' vecchie di
  /// [giorniSincronizzati] giorni se ne vanno.
  ///
  /// Perche' e' sicuro: il sync e' «vince l'ultimo», quindi portare l'**ultimo**
  /// stato di un elemento o portare tutti gli stati intermedi uno dopo l'altro
  /// lascia il mondo nello stesso posto. Quello che sarebbe sbagliato e'
  /// buttare anche l'ultima riga di una modifica mai partita: quella resta.
  ///
  /// Serve perche' finche' non esiste il client OAuth il sync non gira, e ogni
  /// scrittura lascia in coda il suo payload JSON **per sempre**: mesi di uso
  /// normale sono qualche migliaio di righe, cioe' un database che cresce senza
  /// motivo (misurato il 2026-09-23: 2000 scritture su dati veri = ... righe).
  ///
  /// Ritorna quante righe ha tolto.
  int compact({int giorniSincronizzati = 30}) {
    _db.execute(
      '''DELETE FROM outbox
         WHERE sync_state != 'synced'
           AND rowid NOT IN (
             SELECT MAX(rowid) FROM outbox WHERE sync_state != 'synced'
             GROUP BY entity_type, entity_id
           )''',
    );
    final tolteNonSincronizzate = _db.updatedRows;

    final soglia = DateTime.now()
        .subtract(Duration(days: giorniSincronizzati))
        .millisecondsSinceEpoch;
    _db.execute(
      "DELETE FROM outbox WHERE sync_state = 'synced' AND created_at < ?",
      [soglia],
    );

    return tolteNonSincronizzate + _db.updatedRows;
  }
}

/// Chiave/valore per lo stato del sync: cursore remoto, shard già applicati.
class MetaStore {
  MetaStore(this._db);

  final Database _db;

  String? get(String key) {
    final rows = _db.select('SELECT value FROM sync_meta WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void set(String key, String value) {
    _db.execute(
      'INSERT INTO sync_meta (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }
}
