/// Il **nome** e il **foglio di accompagnamento** di una copia di sicurezza.
///
/// Perche' un file suo, senza IO e senza Flutter: nome e foglio sono le due cose
/// che sbagliano in silenzio — una copia con un nome che nessuno riconosce piu'
/// (e che quindi la rotazione non cancella e la pagina non elenca), un foglio con
/// un campo in meno che fa esplodere la lettura, un backup di una versione piu'
/// nuova aperto lo stesso. Qui si provano senza toccare il disco; a leggere e
/// scrivere i file pensa `backup_service.dart`.
library;

/// Perche' esiste una copia.
///
/// Non e' decorazione: e' quello che si legge in Impostazioni e che distingue
/// «la copia di ieri sera» dalla «copia fatta **prima** di un aggiornamento» —
/// cioe' la prima cosa che serve sapere quando qualcosa e' andato storto.
enum BackupReason {
  automatica('automatica'),
  manuale('manuale'),
  emergenza('emergenza'),
  preAggiornamento('prima di un aggiornamento'),
  preRipristino('prima di un ripristino'),

  /// La copia fatta quando i dati passano da una build all'altra (test ↔
  /// ufficiale): e' l'unico momento in cui il codice che legge il database
  /// cambia sotto i dati.
  preCambioBuild('prima di un cambio di build');

  const BackupReason(this.etichetta);

  /// Come si legge in Impostazioni.
  final String etichetta;

  /// Il motivo salvato nel foglio, se e' uno che conosciamo.
  ///
  /// `null` per un valore scritto da una versione piu' nuova (o assente): la
  /// copia resta leggibile e si mostra come «motivo non noto» invece di
  /// spacciarla per automatica.
  static BackupReason? daNome(String? raw) {
    for (final motivo in values) {
      if (motivo.name == raw) return motivo;
    }
    return null;
  }
}

/// Le regole del nome di una copia: `planner-AAAAMMGG-HHmmss.sqlite`.
///
/// Un nome **datato** e ordinabile, con l'eventuale `-2`, `-3` quando due copie
/// cadono nello stesso secondo (succede: la copia di sicurezza prima di un
/// ripristino arriva subito dopo un'altra).
class BackupNaming {
  const BackupNaming._();

  static const String prefisso = 'planner-';
  static const String estensione = '.sqlite';
  // Si **aggiunge** al nome della copia, che finisce gia' con `.sqlite`: il
  // foglio di `planner-20260923-201507.sqlite` e' `planner-20260923-201507.sqlite.json`.
  static const String estensioneFoglio = '.json';

  /// Le due copie di **emergenza**: nome fisso e non datato, cosi' la rotazione
  /// non le tocca mai (la data sta nel foglio).
  static const String emergenzaA = 'planner-emergenza-A.sqlite';
  static const String emergenzaB = 'planner-emergenza-B.sqlite';

  static final RegExp _nostro = RegExp(
    r'^planner-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})(?:-(\d+))?\.sqlite$',
  );

  /// `planner-20260923-201500.sqlite` (o `...-201500-2.sqlite`).
  static String nome(DateTime quando, {int duplicato = 0}) {
    final data = _due(quando.year) + _due(quando.month) + _due(quando.day);
    final ora = _due(quando.hour) + _due(quando.minute) + _due(quando.second);
    final coda = duplicato > 0 ? '-$duplicato' : '';
    return '$prefisso$data-$ora$coda$estensione';
  }

  /// Il foglio che accompagna una copia: sta **accanto** e si chiama come lei.
  static String foglioDi(String nomeCopia) => '$nomeCopia$estensioneFoglio';

  /// Quando e' stata scritta una copia, o `null` se quel nome non e' nostro.
  ///
  /// I numeri si validano uno per uno: `planner-20261345-999999.sqlite` *sembra*
  /// un nome nostro, e un `DateTime` lo accetterebbe in silenzio spostandolo a un
  /// altro giorno — cioe' una copia datata male che la rotazione cancellerebbe
  /// per prima.
  static DateTime? quandoDi(String nome) {
    final match = _nostro.firstMatch(nome);
    if (match == null) return null;

    final anno = int.parse(match.group(1)!);
    final mese = int.parse(match.group(2)!);
    final giorno = int.parse(match.group(3)!);
    final ore = int.parse(match.group(4)!);
    final minuti = int.parse(match.group(5)!);
    final secondi = int.parse(match.group(6)!);

    // I minuti e i secondi non si normalizzano da soli: `DateTime(…, 25, 0, 0)`
    // diventa l'una di notte del giorno dopo, cioe' una copia datata male che
    // passerebbe per buona.
    if (ore > 23 || minuti > 59 || secondi > 59) return null;

    final quando = DateTime(anno, mese, giorno, ore, minuti, secondi);
    // Giorno e mese invece **si** normalizzano (il 31 febbraio diventa il 3
    // marzo): se il risultato non e' quello scritto nel nome, il nome era
    // impossibile. Il mese 13 e il giorno 45 cadono qui senza una riga apposta.
    if (quando.month != mese || quando.day != giorno) return null;
    return quando;
  }

  /// Lo scarto di una copia (`-2`), o `0` per la prima dello stesso secondo.
  static int duplicatoDi(String nome) {
    final match = _nostro.firstMatch(nome);
    final coda = match?.group(7);
    return coda == null ? 0 : int.tryParse(coda) ?? 0;
  }

  static bool eNostro(String nome) => _nostro.hasMatch(nome);

  static String _due(int valore) => valore.toString().padLeft(2, '0');
}

/// Il foglio di accompagnamento: cosa c'era dentro, chi l'ha scritto e quando.
///
/// E' quello che rende una copia **verificabile**: senza, un file da 4 MB si apre
/// solo sperando che sia intero.
class BackupSidecar {
  const BackupSidecar({
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.device,
    required this.counts,
    required this.checksum,
    required this.reason,
  });

  final String appVersion;
  final int schemaVersion;
  final DateTime createdAt;

  /// `android`, `windows`, ... — basta a distinguere due dispositivi diversi
  /// senza chiedere un permesso o una libreria in piu'.
  final String device;

  /// Quante righe per tabella al momento della copia: e' il confronto che dice
  /// «questa copia contiene quello che dice di contenere».
  final Map<String, int> counts;

  /// `fnv1a64` in esadecimale (`core/sync/hash.dart`): niente dipendenza crypto
  /// per accorgersi di un file troncato.
  final String checksum;

  /// Il motivo, se la versione che ha scritto il foglio lo conosceva.
  final BackupReason? reason;

  Map<String, Object?> toJson() => {
        'app_version': appVersion,
        'schema_version': schemaVersion,
        'created_at': createdAt.millisecondsSinceEpoch,
        'device': device,
        'counts': counts,
        'checksum': checksum,
        'reason': reason?.name,
      };

  /// Legge un foglio **con tolleranza**: un campo che manca o ha il tipo storto
  /// non deve far esplodere la pagina delle copie (sarebbe il modo piu' rapido
  /// per non far vedere piu' le copie che ci sono). Se manca l'essenziale si
  /// torna `null`, e la copia si mostra come «senza foglio».
  static BackupSidecar? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final appVersion = raw['app_version'];
    final schemaVersion = raw['schema_version'];
    final createdAt = raw['created_at'];
    final checksum = raw['checksum'];
    if (appVersion is! String ||
        schemaVersion is! int ||
        createdAt is! int ||
        checksum is! String ||
        checksum.isEmpty) {
      return null;
    }

    final counts = <String, int>{};
    final rawCounts = raw['counts'];
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        final valore = entry.value;
        if (entry.key is String && valore is int) {
          counts[entry.key as String] = valore;
        }
      }
    }

    return BackupSidecar(
      appVersion: appVersion,
      schemaVersion: schemaVersion,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      device: raw['device'] is String ? raw['device'] as String : 'sconosciuto',
      counts: counts,
      checksum: checksum,
      reason: BackupReason.daNome(raw['reason'] as String?),
    );
  }

  /// Un foglio di una versione **piu' nuova** di questa non si apre: le sue
  /// tabelle possono avere colonne che qui non esistono, e aprire per vedere e'
  /// il modo di perdere dati in silenzio. Una copia piu' **vecchia** invece si
  /// apre sempre: le migrazioni sono additive.
  bool compatibile(int schemaAttuale) => schemaVersion <= schemaAttuale;

  @override
  String toString() =>
      'BackupSidecar($appVersion, schema $schemaVersion, ${counts.length} tabelle, $checksum)';
}

/// Una copia trovata su disco (o appena scritta).
class BackupFile {
  const BackupFile({
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
    required this.sidecar,
    this.verified = false,
  });

  final String name;
  final DateTime createdAt;
  final int sizeBytes;

  /// `null` = copia senza foglio: leggibile, ma non verificabile e senza motivo.
  final BackupSidecar? sidecar;

  /// Esito dell'ultima verifica fatta **adesso** (integrita' + conteggi).
  final bool verified;

  bool get eEmergenza =>
      name == BackupNaming.emergenzaA || name == BackupNaming.emergenzaB;

  /// Il motivo da mostrare: quello del foglio, o quello dedotto dal nome.
  BackupReason? get reason =>
      sidecar?.reason ?? (eEmergenza ? BackupReason.emergenza : null);
}
