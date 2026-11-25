import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/app_version.dart';
import '../../core/database/database_files.dart';
import '../../core/database/database_service.dart';
import '../../core/storage_failure.dart';
import '../../core/database/schema.dart';
import 'backup_attachment_files.dart';
import 'backup_verify.dart';
import 'domain/backup_file.dart';

part 'backup_external.dart';

/// Cosa e' andato storto in una copia o in un ripristino, in una riga che si
/// puo' **mostrare**: chi legge deve sapere se riprovare o se e' il caso di
/// preoccuparsi.
class BackupFallito implements Exception {
  BackupFallito(this.messaggio);

  final String messaggio;

  @override
  String toString() => messaggio;
}

/// Le copie di sicurezza del database.
///
/// Tre cose, in quest'ordine di importanza: **scrivere** una copia che si puo'
/// verificare, **verificarla** davvero (integrita', conteggi, checksum),
/// **rimetterla dentro** senza inventarsi niente. Il resto — rotazione, copie di
/// emergenza, dimensioni — serve a far funzionare le tre di sopra per mesi.
///
/// La copia si fa con `VACUUM INTO`: e' l'unico modo di copiare un database
/// SQLite **aperto** (e in WAL) che non produca un file a meta' fra una pagina e
/// l'altra.
class BackupService {
  BackupService(
    this._database, {
    required this.cartella,
    DateTime Function()? adesso,
    String Function()? dispositivo,
  })  : _adesso = adesso ?? DateTime.now,
        _dispositivo = dispositivo ?? _dispositivoDiSistema;

  final DatabaseService _database;

  /// La cartella delle copie (iniettabile: i test usano una cartella temporanea).
  final Directory cartella;

  final DateTime Function() _adesso;
  final String Function() _dispositivo;

  /// Cartella privata su Android, Documenti/Planner/Backup su desktop.
  static Future<Directory> cartellaPredefinita() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final base = await getApplicationSupportDirectory();
      return Directory(p.join(base.path, 'backup'));
    }
    final documenti = await getApplicationDocumentsDirectory();
    return Directory(p.join(documenti.path, 'Planner', 'Backup'));
  }

  // ─── Scrivere ─────────────────────────────────────────

  /// Una copia nuova, con il suo foglio.
  Future<BackupFile> snapshot({
    BackupReason motivo = BackupReason.automatica,
  }) async {
    final quando = _adesso();
    // Due copie nello stesso secondo succedono davvero (una manuale e subito
    // dopo quella di prima di un ripristino): la seconda prende un numero, e si
    // parte da `-2` perche' e' appunto la **seconda**.
    var nome = BackupNaming.nome(quando);
    var duplicato = 1;
    while (File(p.join(cartella.path, nome)).existsSync()) {
      duplicato++;
      nome = BackupNaming.nome(quando, duplicato: duplicato);
    }

    return _scrivi(nome: nome, quando: quando, motivo: motivo);
  }

  /// La copia di **emergenza**: due posti fissi che si alternano, fuori dalla
  /// rotazione.
  ///
  /// Serve contro il caso che conta davvero: le ultime copie sono tutte rotte
  /// (un disco che si sta guastando, una scrittura interrotta) e la rotazione le
  /// ha ormai cancellate tutte. Lo slot si sostituisce **solo** quando la copia
  /// nuova passa la verifica, quindi almeno una delle due e' sempre buona.
  Future<BackupFile> emergenza() async {
    final quando = _adesso();
    final a = File(p.join(cartella.path, BackupNaming.emergenzaA));
    final b = File(p.join(cartella.path, BackupNaming.emergenzaB));

    // Si riscrive il piu' **vecchio** dei due (o quello che manca): l'altro
    // resta com'e' finche' la verifica non e' passata.
    final toccaA = !a.existsSync() ||
        (b.existsSync() && b.lastModifiedSync().isAfter(a.lastModifiedSync()));
    final nome = toccaA ? BackupNaming.emergenzaA : BackupNaming.emergenzaB;

    return _scrivi(nome: nome, quando: quando, motivo: BackupReason.emergenza);
  }

  Future<BackupFile> _scrivi({
    required String nome,
    required DateTime quando,
    required BackupReason motivo,
  }) async {
    await cartella.create(recursive: true);
    final destinazione = File(p.join(cartella.path, nome));
    final temporaneo = File('${destinazione.path}.tmp');

    try {
      _database.instance
          .execute("VACUUM INTO '${percorsoSql(temporaneo.path)}'");
    } on SqliteException catch (errore) {
      if (temporaneo.existsSync()) temporaneo.deleteSync();
      throw BackupFallito(isDeviceStorageFull(errore)
          ? deviceStorageFullMessage
          : 'Copia non riuscita. Riprova.');
    }

    final esito = await verificaCopia(temporaneo);
    if (!esito.ok) {
      temporaneo.deleteSync();
      throw BackupFallito('La copia non ha superato la verifica. Riprova.');
    }

    await _salvaAllegati(temporaneo);

    // Il nome definitivo (e la sostituzione di una copia vecchia) arrivano solo
    // **dopo** la verifica: una copia scritta male non deve prendere il posto di
    // una buona.
    final foglio = BackupSidecar(
      appVersion: AppVersion.full,
      schemaVersion: schemaVersion,
      createdAt: quando,
      device: _dispositivo(),
      counts: esito.conteggi,
      checksum: esito.checksum,
      reason: motivo,
    );
    final scheda = p.join(cartella.path, BackupNaming.foglioDi(nome));
    final schedaTemporanea = File('$scheda.tmp');
    try {
      await schedaTemporanea.writeAsString(jsonEncode(foglio.toJson()),
          flush: true);
      await temporaneo.rename(destinazione.path);
      await schedaTemporanea.rename(scheda);
    } finally {
      if (await temporaneo.exists()) await temporaneo.delete();
      if (await schedaTemporanea.exists()) await schedaTemporanea.delete();
    }

    return BackupFile(
      name: nome,
      createdAt: quando,
      sizeBytes: destinazione.lengthSync(),
      sidecar: foglio,
      verified: true,
    );
  }

  // ─── Leggere e verificare ─────────────────────────────

  /// Le copie che ci sono, dalla piu' recente.
  ///
  /// I file che non riconosciamo (nomi di altre app, file temporanei rimasti da
  /// una scrittura interrotta) si **ignorano**: non si elencano e non si
  /// toccano.
  Future<List<BackupFile>> elenco() async {
    if (!await cartella.exists()) return const [];

    final copie = <BackupFile>[];
    await for (final voce in cartella.list()) {
      if (voce is! File) continue;
      final nome = p.basename(voce.path);
      final quando = BackupNaming.quandoDi(nome);
      final emergenza =
          nome == BackupNaming.emergenzaA || nome == BackupNaming.emergenzaB;
      if (quando == null && !emergenza) continue;

      final foglio = _leggiFoglio(nome);
      copie.add(BackupFile(
        name: nome,
        createdAt: foglio?.createdAt ?? quando ?? await voce.lastModified(),
        sizeBytes: await voce.length(),
        sidecar: foglio,
      ));
    }

    copie.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copie;
  }

  /// Verifica la copia a partire dal nome.
  Future<EsitoVerifica> verifica(String nome) =>
      verificaCopia(File(p.join(cartella.path, nome)));

  // ─── Ripristinare ─────────────────────────────────────

  /// Rimette dentro una copia. Prima fa una copia di **sicurezza** di quello che
  /// c'e' adesso, cosi' un ripristino sbagliato si annulla con un altro
  /// ripristino.
  ///
  /// Torna la copia di sicurezza appena scritta.
  Future<BackupFile> ripristina(BackupFile copia) async {
    final file = File(p.join(cartella.path, copia.name));
    final esito = await verificaCopia(file);
    if (!esito.ok) {
      throw BackupFallito('La copia è illeggibile. Scegli un’altra copia.');
    }

    final foglio = copia.sidecar ?? _leggiFoglio(copia.name);
    if (foglio != null && !foglio.compatibile(schemaVersion)) {
      throw BackupFallito(
        'Questa copia richiede una versione più nuova. Aggiorna Acta e riprova.',
      );
    }
    if (foglio != null && foglio.checksum != esito.checksum) {
      throw BackupFallito(
          'La copia non coincide con quella verificata. Scegli un’altra copia.');
    }

    return _applica(file);
  }

  Future<BackupFile> ripristinaEsterna(String percorso) =>
      _ripristinaDaFileEsterno(percorso, _applica);

  // ─── Manutenzione ─────────────────────────────────────

  /// Cancella le copie oltre le [retention] piu' recenti.
  ///
  /// Le due copie di **emergenza** non si toccano mai, e si cancella solo quello
  /// che riconosciamo come nostro — piu' il suo foglio. Un file estraneo nella
  /// cartella non e' affar nostro.
  Future<List<String>> rotazione(int retention) async {
    final quante = retention.clamp(3, 50);
    final copie = (await elenco()).where((c) => !c.eEmergenza).toList();

    // La copia **subito prima dell'ultimo aggiornamento** non si cancella:
    // e' la via per tornare indietro se una versione nuova legge male i dati.
    // Resta fuori dalla rotazione finche' non ne arriva una piu' recente.
    BackupFile? preAggiornamento;
    for (final copia in copie) {
      if (copia.reason == BackupReason.preAggiornamento) {
        preAggiornamento = copia;
        break;
      }
    }
    final daTenere = copie.take(quante).map((c) => c.name).toSet();
    if (preAggiornamento != null) daTenere.add(preAggiornamento.name);

    final cancellate = <String>[];
    for (final copia in copie) {
      if (daTenere.contains(copia.name)) continue;
      File(p.join(cartella.path, copia.name)).deleteSync();
      final foglio =
          File(p.join(cartella.path, BackupNaming.foglioDi(copia.name)));
      if (foglio.existsSync()) foglio.deleteSync();
      cancellate.add(copia.name);
    }
    return cancellate;
  }

  /// Quanto occupa tutto quello che sta nella cartella delle copie.
  Future<int> dimensione() async {
    if (!await cartella.exists()) return 0;
    var totale = 0;
    await for (final voce in cartella.list()) {
      if (voce is File) totale += await voce.length();
    }
    return totale;
  }

  // ─── Interni ──────────────────────────────────────────

  /// Il foglio di una copia, se c'e' e si lascia leggere.
  ///
  /// Un foglio illeggibile **non** fa sparire la copia: la copia e' il file che
  /// conta, il foglio e' un di piu'.
  BackupSidecar? _leggiFoglio(String nomeCopia) {
    final file = File(p.join(cartella.path, BackupNaming.foglioDi(nomeCopia)));
    if (!file.existsSync()) return null;
    try {
      return BackupSidecar.fromJson(jsonDecode(file.readAsStringSync()));
    } on FormatException {
      return null;
    }
  }

  static String _dispositivoDiSistema() => Platform.operatingSystem;
}
