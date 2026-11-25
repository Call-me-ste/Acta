import 'dart:io';

import 'database_service.dart';

/// Le tabelle che sono **dati**: quelle che una copia porta con sé e che un
/// ripristino rimette a posto.
///
/// Fuori di proposito:
/// * `app_settings` — le preferenze (tema, vista, cartella di backup) sono **di
///   questo device**: ripristinare i dati di ieri non deve cambiare il tema di
///   oggi, e su un telefono nuovo le preferenze del vecchio non servono.
/// * `sync_meta` — il cursore del sync e gli shard «già applicati» appartengono
///   al database da cui vengono: dopo un ripristino si dimenticano apposta (vedi
///   [FileDelDatabase.dimenticaStatoDiSync]).
const List<String> tabelleDati = [
  'events',
  'todos',
  'note_folders',
  'notes',
  'note_attachments',
  'note_links',
  'categories',
  'palettes',
  'occurrence_overrides',
  'outbox',
];

/// Un percorso dentro una stringa SQL.
///
/// `VACUUM INTO` e `ATTACH` vogliono il nome del file **dentro** l'SQL, non come
/// parametro: gli apici si raddoppiano come vuole lo standard, e un percorso con
/// un apice dentro (esiste) non rompe la query.
String percorsoSql(String percorso) => percorso.replaceAll("'", "''");

/// Quanto pesano i file del database.
class DimensioniDatabase {
  const DimensioniDatabase({
    required this.database,
    required this.wal,
    required this.appoggio,
  });

  final int database;
  final int wal;
  final int appoggio;

  int get totale => database + wal + appoggio;
}

/// La chiave che dice che la manutenzione una-tantum dei file e' gia' stata
/// fatta (sta in `sync_meta`: e' una nota su **questo** database, non un dato da
/// sincronizzare).
const String _flagManutenzione = 'fileMaintenance';

/// Quando e' stata fatta l'ultima **compattazione automatica** (in millisecondi).
///
/// Senza questa memoria la compattazione girerebbe a ogni avvio: un `VACUUM` su un
/// database grande si sente, e per una coda gia' compatta sarebbe lavoro buttato.
const String _flagCompattazione = 'lastCompactAt';

/// Ogni quanto si ricontrolla, se c'e' qualcosa da restituire.
const Duration _intervalloCompattazione = Duration(days: 7);

/// Le operazioni del database che riguardano **i file**, non le righe.
///
/// Stanno fuori da `database_service.dart` per due motivi: quel file ha un
/// budget di 300 righe, e «le righe» e «i file» sono due mestieri diversi — il
/// primo si legge per sapere come sono fatti i dati, il secondo si tocca solo
/// quando si fa una copia, un ripristino o una misura.
extension FileDelDatabase on DatabaseService {
  /// Quanto occupa il database, e quanto i suoi due file di appoggio del WAL.
  ///
  /// Il WAL può arrivare a pesare quanto il database: mostrarne solo uno dei due
  /// sarebbe una mezza verità, ed è esattamente la mezza verità che fa dire «non
  /// ho spazio» senza sapere dove sia finito.
  DimensioniDatabase dimensioni() {
    int misura(String suffisso) {
      final file = File('$path$suffisso');
      return file.existsSync() ? file.lengthSync() : 0;
    }

    return DimensioniDatabase(
      database: misura(''),
      wal: misura('-wal'),
      appoggio: misura('-shm'),
    );
  }

  /// Porta il WAL dentro il file principale.
  ///
  /// Serve in due momenti: quando l'app va in pausa — perché il backup
  /// automatico **di Android** legge i file, e senza checkpoint copierebbe un
  /// database più vecchio dell'ultima modifica — e prima di una copia fatta da
  /// fuori. Costa quanto il WAL che si porta dietro (con le scritture di una
  /// giornata: poche decine di KB), e si fa quando non sta animando niente.
  void checkpoint() {
    instance.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  /// `PRAGMA integrity_check` sul database **vivo**: `'ok'` o il guaio trovato.
  String integrita() {
    final esito = instance.select('PRAGMA integrity_check').first.values.first;
    return esito is String ? esito : '$esito';
  }

  /// Le righe per tabella ([tabelleDati]): è quello che si mostra in
  /// Impostazioni e quello che si confronta con una copia per dire «dentro c'è
  /// quello che dice di contenere».
  Map<String, int> conteggi() {
    final conteggi = <String, int>{};
    for (final tabella in tabelleDati) {
      conteggi[tabella] = instance
          .select('SELECT COUNT(*) AS n FROM $tabella')
          .first['n'] as int;
    }
    return conteggi;
  }

  /// Quando e' stata toccata l'ultima riga di dati (il massimo `updated_at`).
  ///
  /// Serve a decidere se una copia automatica vale la pena: se dopo l'ultima
  /// copia non e' cambiato niente, fotografare di nuovo produce solo rumore
  /// nella cartella (e nella testa di chi le guarda).
  DateTime? ultimoCambio() {
    int? massimo;
    for (final tabella in tabelleDati) {
      // `outbox` non ha `updated_at`: si guardano le tabelle che ce l'hanno.
      if (!_colonne('main', tabella).contains('updated_at')) continue;
      final valore = instance
          .select('SELECT MAX(updated_at) AS t FROM $tabella')
          .first['t'];
      if (valore is int && (massimo == null || valore > massimo)) {
        massimo = valore;
      }
    }
    return massimo == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(massimo);
  }

  /// La manutenzione **una volta sola** su un database che esiste da prima:
  /// accende `auto_vacuum = INCREMENTAL` e restituisce lo spazio delle righe gia'
  /// cancellate.
  ///
  /// Su un database gia' creato `auto_vacuum` non si accende da solo: il pragma
  /// ha effetto **dopo** un `VACUUM`, quindi i due comandi stanno insieme. Il
  /// flag dice che e' stato fatto: senza, ogni avvio rifarebbe un `VACUUM` — che
  /// su un database grande si sente.
  ///
  /// Misurato il 2026-09-23 su un database di prova cresciuto a 852 KB con 2000
  /// scritture in coda: dopo aver cancellato 1800 righe c'erano **160 pagine
  /// libere (640 KB)** e `PRAGMA incremental_vacuum` non le restituiva — senza
  /// `auto_vacuum` e' un comando che non fa niente. Con `VACUUM` il file e'
  /// tornato a **204 KB** (213 -> 51 pagine).
  ({int bytePrima, int byteDopo}) manutenzioneUnaTantum() {
    if (meta.get(_flagManutenzione) == '1') {
      return (bytePrima: 0, byteDopo: 0);
    }

    final prima = dimensioni().totale;
    instance.execute('PRAGMA auto_vacuum = INCREMENTAL');
    instance.execute('VACUUM');
    // Il WAL si riporta dentro il file principale: subito dopo un `VACUUM` puo'
    // contenere una copia intera del database, e misurarlo li' direbbe che il
    // file e' **cresciuto** (misurato la prima volta: 852 KB -> 1053 KB, di cui
    // 850 di WAL).
    checkpoint();
    meta.set(_flagManutenzione, '1');
    return (bytePrima: prima, byteDopo: dimensioni().totale);
  }

  /// La manutenzione **a richiesta** (il comando «Compatta adesso»): compatta la
  /// coda delle scritture e restituisce lo spazio al disco.
  ///
  /// E' l'unica via per riavere indietro lo spazio, perche' `incremental_vacuum`
  /// da solo non fa niente se `auto_vacuum` non e' acceso (vedi
  /// [manutenzioneUnaTantum]: dopo quella, invece, funziona).
  ({int righe, int bytePrima, int byteDopo}) compatta() {
    final prima = dimensioni().totale;
    final righe = outbox.compact();
    instance.execute('VACUUM');
    // Vedi il commento in [manutenzioneUnaTantum]: dopo un `VACUUM` il WAL puo'
    // contenere il database intero.
    checkpoint();
    return (righe: righe, bytePrima: prima, byteDopo: dimensioni().totale);
  }

  /// La compattazione **automatica**: compatta la coda e restituisce lo spazio, ma
  /// solo se serve davvero.
  ///
  /// Tre cancelli, in ordine di costo: sono passati piu' di sette giorni
  /// dall'ultima volta (`forza` li salta: all'esportazione si vuole la copia di
  /// adesso, compatta) — c'e' qualcosa da togliere dalla coda — il file ha pagine
  /// libere da restituire. Se nessuno dei tre e' aperto non si tocca niente, e
  /// torna `null`: e' la norma, ed e' il motivo per cui questa puo' girare a ogni
  /// avvio senza farsi sentire.
  ({int righe, int bytePrima, int byteDopo})? compattaSeServe({
    bool forza = false,
    DateTime? adesso,
  }) {
    final ora = adesso ?? DateTime.now();
    final ultima = _millis(meta.get(_flagCompattazione));
    if (!forza &&
        ultima != null &&
        ora.difference(ultima) < _intervalloCompattazione) {
      return null;
    }
    if (outbox.compactableCount() <= 0 && _pagineLibere() <= 0) return null;

    final esito = compatta();
    meta.set(_flagCompattazione, '${ora.millisecondsSinceEpoch}');
    return esito;
  }

  /// Le pagine che il file ha libere (righe cancellate ma non ancora restituite).
  int _pagineLibere() =>
      instance.select('PRAGMA freelist_count').first.values.first as int;

  static DateTime? _millis(String? raw) {
    final valore = int.tryParse(raw ?? '');
    return valore == null ? null : DateTime.fromMillisecondsSinceEpoch(valore);
  }

  /// Rimette dentro il database il contenuto di una **copia verificata**.
  ///
  /// A righe, tabella per tabella, in una transazione sola: o si ripristina
  /// tutto, o non si ripristina niente (un database mezzo ripristinato sarebbe
  /// peggio di uno non ripristinato, perché sembrerebbe a posto).
  ///
  /// Perché a righe e non sostituendo il file: il file si può sostituire solo con
  /// la connessione **chiusa**, e chiudere significa rifare tutte le viste sul
  /// database (provider, store, cache) — il modo più facile per lasciare in giro
  /// un pezzo che punta al database di prima. A righe, in più, lo schema resta
  /// quello di **adesso** (migrazioni già applicate) e una copia vecchia non va
  /// ri-migrata: le colonne che la copia non ha restano ai loro valori di
  /// partenza.
  void ripristinaDa(File copia) {
    instance.execute("ATTACH DATABASE '${percorsoSql(copia.path)}' AS copia");
    try {
      runInTransaction(() {
        for (final tabella in tabelleDati) {
          final colonneDellaCopia = _colonne('copia', tabella);
          // Una tabella che la copia non ha: è di una versione più vecchia (una
          // funzione che allora non c'era), non un errore.
          if (colonneDellaCopia.isEmpty) {
            if (tabella == 'note_attachments') {
              instance.execute('DELETE FROM note_attachments');
            }
            continue;
          }

          final colonneQui = _colonne('main', tabella).toSet();
          final comuni = colonneDellaCopia.where(colonneQui.contains).toList();
          if (comuni.isEmpty) continue;

          final elenco = comuni.join(', ');
          instance.execute('DELETE FROM $tabella');
          instance.execute(
            'INSERT INTO $tabella ($elenco) SELECT $elenco FROM copia.$tabella',
          );
        }
        dimenticaStatoDiSync();
      });
    } finally {
      instance.execute('DETACH DATABASE copia');
    }
  }

  /// Dimentica lo stato del sync: cursore remoto e shard «già applicati».
  ///
  /// Dopo un ripristino quelle chiavi descrivono il database **di prima**: se
  /// restassero, il dispositivo crederebbe di essere già allineato e non
  /// tirerebbe giù niente dal cloud — cioè il ripristino vecchio vincerebbe
  /// sulla sincronizzazione nuova, in silenzio.
  void dimenticaStatoDiSync() {
    instance.execute(
      "DELETE FROM sync_meta WHERE key = 'remote_cursor' "
      "OR key GLOB 'shard:*' OR key GLOB 'applied:*'",
    );
    final revision = int.tryParse(meta.get(syncReplayKey) ?? '') ?? 0;
    meta.set(syncReplayKey, '${revision + 1}');
  }

  /// Le colonne di una tabella, `''` se la tabella non esiste.
  List<String> _colonne(String schema, String tabella) {
    final righe = instance.select('PRAGMA $schema.table_info($tabella)');
    return [for (final riga in righe) riga['name'] as String];
  }
}

const syncReplayKey = 'sync_replay_revision';
