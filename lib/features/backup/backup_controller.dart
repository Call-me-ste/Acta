import 'package:flutter/foundation.dart';

import '../../core/database/database_files.dart';
import '../../core/database/database_service.dart';
import '../../core/storage_failure.dart';
import '../../core/dev_flags.dart';
import '../settings/app_settings_controller.dart';
import 'backup_service.dart';
import 'domain/backup_file.dart';

/// Le copie **viste dall'app**: quando farne una, come ripristinarla, e cosa
/// dire all'utente quando qualcosa non torna.
///
/// Il mestiere del servizio e' scrivere e verificare file; qui c'e' il mestiere
/// della decisione — «una al giorno, e solo se e' cambiato qualcosa», «tieni
/// fresco il posto di emergenza», «dopo un ripristino la pagina deve mostrare il
/// mondo nuovo» — piu' lo stato che la pagina delle Impostazioni legge.
///
/// La regola di fondo: **un errore non fa cadere l'app**. La copia automatica
/// gira all'avvio, e un telefono pieno o una cartella sparita non devono
/// impedire di usare il planner: l'errore finisce in [errore] e lo si legge in
/// Impostazioni.
class BackupController extends ChangeNotifier {
  BackupController(
    this._database,
    this._settings, {
    required this.servizio,
    DateTime Function()? adesso,
  }) : _adesso = adesso ?? DateTime.now;

  final DatabaseService _database;
  final AppSettingsController _settings;
  final BackupService servizio;
  final DateTime Function() _adesso;

  /// Una copia al giorno al massimo: piu' spesso di cosi' la copia di oggi e
  /// quella di ieri contengono le stesse cose, e a riempire la cartella e' solo
  /// rumore.
  static const Duration _intervalloAutomatico = Duration(hours: 20);

  /// Il posto di emergenza si rinfresca di rado: serve a trovarsi una copia
  /// **ferma nel tempo** anche se le ultime dieci sono tutte rotte. Ogni copia
  /// e' un `VACUUM INTO` completo, quindi non e' roba da fare a ogni avvio.
  static const Duration _intervalloEmergenza = Duration(days: 7);

  bool _occupato = false;
  String? _errore;
  List<BackupFile> _copie = const [];
  int _dimensioneCopie = 0;

  bool get occupato => _occupato;

  /// L'ultimo guaio, in una riga da mostrare. Si azzera alla copia riuscita
  /// successiva.
  String? get errore => _errore;

  List<BackupFile> get copie => _copie;
  int get dimensioneCopie => _dimensioneCopie;

  /// L'ultima copia fatta **prima di un aggiornamento**, se c'e'. La rotazione
  /// non la cancella: e' la via per tornare indietro se una versione nuova legge
  /// male i dati.
  BackupFile? get copiaPreAggiornamento {
    for (final copia in _copie) {
      if (copia.reason == BackupReason.preAggiornamento) return copia;
    }
    return null;
  }

  /// Quanto pesa il database **adesso** (compresi i file di appoggio del WAL).
  DimensioniDatabase get dimensioniDatabase => _database.dimensioni();

  DateTime? get ultimaCopia => _copie.firstOrNull?.createdAt;

  int get retention => _settings.backupRetention;

  /// Cambia quante copie si tengono. La rotazione vera la fa la copia
  /// successiva: qui si scrive la preferenza, e la cartella si allinea da sola
  /// (senza cancellare niente **adesso**, che sarebbe una sorpresa mentre si
  /// sposta un cursore).
  void cambiaRetention(int quante) {
    _settings.setBackupRetention(quante);
    notifyListeners();
  }

  String get percorsoCartella => servizio.cartella.path;
  int get schemaVersion => _database.currentSchemaVersion;

  /// Legge lo stato dalla cartella (copie e dimensioni).
  Future<void> carica() async {
    try {
      _copie = await servizio.elenco();
      _dimensioneCopie = await servizio.dimensione();
    } catch (error) {
      _errore = isDeviceStorageFull(error)
          ? deviceStorageFullMessage
          : 'Impossibile leggere le copie sul dispositivo. Riprova.';
    }
    notifyListeners();
  }

  /// Una copia **adesso**, a richiesta.
  Future<void> adesso() => _fai(motivo: BackupReason.manuale);

  Future<void> primaDiAggiornare() =>
      _fai(motivo: BackupReason.preAggiornamento);

  /// La copia automatica dell'avvio: una al giorno, e solo se dopo l'ultima e'
  /// cambiato qualcosa. In piu' tiene fresco il posto di emergenza.
  Future<void> autoSeDovuta() async {
    await carica();

    // **Prima di tutto**: se i dati li ha scritti un'altra build, la copia va
    // fatta adesso. E' l'unico momento in cui cambia il codice che legge il
    // database, e la copia automatica di sotto non basta: guarda se i **dati**
    // sono cambiati, non se e' cambiata la build.
    await _copiaAlCambioDiBuild();

    final cambiato = _database.ultimoCambio();
    // Nessun dato (installazione appena fatta): non c'e' niente da copiare, e
    // una cartella di database vuoti — emergenza compresa — non aiuta nessuno.
    if (cambiato == null) return;

    if (_serveLaCopia(cambiato)) {
      await _fai(motivo: BackupReason.automatica);
    }
    await _aggiornaEmergenza();
  }

  /// Rimette dentro una copia e rilegge lo stato.
  ///
  /// Chi chiama deve poi **rileggere i provider**: dopo un ripristino il
  /// database contiene righe che le viste non hanno mai visto.
  Future<void> ripristina(BackupFile copia) =>
      _ripristina(() => servizio.ripristina(copia));

  Future<void> ripristinaEsterna(String percorso) =>
      _ripristina(() => servizio.ripristinaEsterna(percorso));

  Future<void> _ripristina(Future<BackupFile> Function() applica) async {
    if (_occupato) return;
    _occupato = true;
    _errore = null;
    notifyListeners();
    try {
      final sicurezza = await applica();
      _settings.markBackupDone(sicurezza.createdAt);
      await carica();
    } on BackupFallito catch (errore) {
      _errore = errore.messaggio;
    } catch (errore) {
      _errore = isDeviceStorageFull(errore)
          ? deviceStorageFullMessage
          : 'Ripristino non riuscito. Prova un’altra copia.';
    } finally {
      _occupato = false;
      notifyListeners();
    }
  }

  /// «Compatta adesso»: compatta la coda delle scritture e restituisce lo spazio
  /// al disco. Torna i numeri dell'operazione, o `null` se non e' riuscita (il
  /// motivo e' in [errore]).
  ///
  /// I numeri tornano al chiamante invece di diventare una frase qui: questo
  /// livello non conosce le parole che si leggono a schermo.
  Future<({int righe, int bytePrima, int byteDopo})?> compatta() async {
    _occupato = true;
    _errore = null;
    notifyListeners();
    try {
      final esito = _database.compatta();
      await carica();
      return esito;
    } catch (errore) {
      _errore = isDeviceStorageFull(errore)
          ? deviceStorageFullMessage
          : 'Impossibile liberare spazio adesso. Riprova.';
      return null;
    } finally {
      _occupato = false;
      notifyListeners();
    }
  }

  /// Verifica una copia e torna la riga da mostrare: quello che c'e' dentro, o
  /// il guaio trovato.
  Future<String> verifica(BackupFile copia) async {
    final esito = await servizio.verifica(copia.name);
    if (!esito.ok) return 'Danneggiata: ${esito.problema}';

    final righe = esito.conteggi.entries
        .where((voce) => voce.value > 0)
        .map((voce) => '${voce.value} ${voce.key}')
        .join(', ');
    return righe.isEmpty ? 'Vuota, ma leggibile' : 'Integra: $righe';
  }

  /// Cambia la cartella delle copie (usata dal desktop e dai test).
  Future<BackupFile> emergenza() => servizio.emergenza();

  // ─── Interni ──────────────────────────────────────────

  /// La copia quando i dati passano da una build all'altra (test ↔ ufficiale).
  ///
  /// Chiave **assente** = installazione nuova: non c'e' niente di scritto da
  /// un'altra build, quindi nessuna copia, si scrive e basta. Chiave diversa =
  /// i dati vengono da un'altra build: copia col motivo suo, e la chiave si
  /// aggiorna **dopo** che e' riuscita — se fallisse, al prossimo avvio si
  /// riprova invece di dimenticare il cambio.
  Future<void> _copiaAlCambioDiBuild() async {
    final precedente = _settings.buildKind;
    if (precedente == buildKind) return;
    if (precedente != null) {
      await _fai(motivo: BackupReason.preCambioBuild);
      if (_errore != null) return;
    }
    _settings.setBuildKind(buildKind);
  }

  /// Vero se una copia automatica **serve**: e' passato abbastanza tempo
  /// dall'ultima e i dati sono cambiati dopo di lei.
  bool _serveLaCopia(DateTime cambiato) {
    final ultima = _settings.lastBackupAt;
    if (ultima != null &&
        _adesso().difference(ultima) < _intervalloAutomatico) {
      return false;
    }
    return ultima == null || cambiato.isAfter(ultima);
  }

  Future<void> _aggiornaEmergenza() async {
    final ultima = _copie
        .where((copia) => copia.eEmergenza)
        .fold<DateTime?>(null, (massimo, copia) {
      final quando = copia.createdAt;
      if (massimo == null || quando.isAfter(massimo)) return quando;
      return massimo;
    });
    if (ultima != null && _adesso().difference(ultima) < _intervalloEmergenza) {
      return;
    }

    try {
      await servizio.emergenza();
      await carica();
    } on BackupFallito catch (errore) {
      _errore = errore.messaggio;
      notifyListeners();
    } catch (error) {
      _errore = isDeviceStorageFull(error)
          ? deviceStorageFullMessage
          : 'Copia di emergenza non riuscita. Riprova.';
      notifyListeners();
    }
  }

  Future<void> _fai({required BackupReason motivo}) async {
    if (_occupato) return;
    _occupato = true;
    _errore = null;
    notifyListeners();
    try {
      final copia = await servizio.snapshot(motivo: motivo);
      // La data dell'ultima copia si scrive **dopo** che la copia esiste: se
      // l'app morisse a meta', l'avvio dopo rifarebbe la copia invece di credere
      // di averla gia' fatta.
      _settings.markBackupDone(copia.createdAt);
      await servizio.rotazione(_settings.backupRetention);
      await carica();
    } on BackupFallito catch (errore) {
      _errore = errore.messaggio;
    } catch (errore) {
      _errore = isDeviceStorageFull(errore)
          ? deviceStorageFullMessage
          : 'Copia non riuscita. Riprova.';
    } finally {
      _occupato = false;
      notifyListeners();
    }
  }
}
