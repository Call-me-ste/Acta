/// I **cluster** della griglia ore: gli elementi che si sovrappongono a catena,
/// e il cap a due caselle per cluster.
///
/// Logica pura (minuti dalla mezzanotte, niente widget): è ciò che permette di
/// verificarla con un test invece che guardando uno schermo.
///
/// Il raggruppamento è **transfrontiera**: un elemento entra nel cluster
/// corrente finché il suo inizio è strettamente prima della fine più lontana
/// raggiunta fino a quel punto. Due elementi che si toccano (`fine == inizio`)
/// aprono un cluster nuovo — è la stessa regola `!isAfter` di `DayLayout`: non
/// si sovrappongono, quindi possono stare nella stessa corsia.
///
/// Dentro ogni cluster si vedono le **prime 2 caselle** per orino di inizio
/// (stabile a parità: l'ordine dato è l'ordine di disegno) e il resto diventa
/// il bollino «+N», che occupa l'intera finestra del cluster.
library;

/// Quante caselle si vedono in un cluster. Oltre questo, il bollino.
const int capCluster = 2;

/// Un cluster con il suo cap applicato.
class Cluster<T> {
  const Cluster({
    required this.visibili,
    required this.nascosti,
    required this.inizio,
    required this.fine,
  });

  /// Le caselle che si disegnano: al più [capCluster], per orino di inizio.
  final List<T> visibili;

  /// Il resto del cluster: il bollino li conta, il foglio li mostra.
  final List<T> nascosti;

  /// La finestra di unione del cluster (minuti dalla mezzanotte): è lì che
  /// sta il bollino — il «+N» appartiene al conflitto, non ai soli nascosti.
  final int inizio;
  final int fine;

  bool get haBollino => nascosti.isNotEmpty;

  /// Le corsie che il cluster occupa: le caselle visibili e, se c'è, il
  /// bollino nell'ultima. I cluster sono disgiunti nel tempo, quindi le corsie
  /// si ricominciano da zero in ognuno senza collisioni.
  int get corsie => haBollino ? visibili.length + 1 : visibili.length;
}

/// Raggruppa gli elementi `(elemento, inizio, fine)` in cluster e applica il
/// cap a [capCluster] caselle.
///
/// Gli intervalli devono avere `fine > inizio` (chi li passa li ha già limitati
/// alla giornata, come fa `DayLayout`). L'ordine di disegno fra elementi con lo
/// stesso inizio è **l'ordine dato**: a parità l'ordine non salta fra due
/// ricostruzioni.
List<Cluster<T>> clusterDi<T>(List<(T, int, int)> elementi) {
  if (elementi.isEmpty) return const [];

  final ordine = [for (var i = 0; i < elementi.length; i++) i]
    ..sort((a, b) {
      final perInizio = elementi[a].$2.compareTo(elementi[b].$2);
      return perInizio != 0 ? perInizio : a.compareTo(b);
    });

  final clusters = <Cluster<T>>[];
  var corrente = <(T, int, int)>[];
  var fineMassima = 0;

  void chiudi() {
    if (corrente.isEmpty) return;
    clusters.add(Cluster(
      visibili: [
        for (var k = 0; k < corrente.length && k < capCluster; k++)
          corrente[k].$1,
      ],
      nascosti: [
        for (var k = capCluster; k < corrente.length; k++) corrente[k].$1,
      ],
      inizio: corrente.first.$2,
      fine: fineMassima,
    ));
    corrente = [];
  }

  for (final i in ordine) {
    final (elemento, inizio, fine) = elementi[i];
    // `>=`: un elemento che comincia dove l'altro finisce tocca il cluster, non
    // lo attraversa — e due cluster che si toccano stanno in corsie separate.
    if (corrente.isNotEmpty && inizio >= fineMassima) {
      chiudi();
      fineMassima = fine;
    } else if (fine > fineMassima) {
      fineMassima = fine;
    }
    corrente.add((elemento, inizio, fine));
  }
  chiudi();
  return clusters;
}

/// Quante corsie servono per un giorno intero, dato i suoi cluster: la più
/// alta, almeno 1 (un giorno senza elementi non è zero colonne — è la stessa
/// regola di `DayLayout.quante`).
int corsieDeiCluster<T>(Iterable<Cluster<T>> clusters) {
  var massime = 1;
  for (final cluster in clusters) {
    if (cluster.corsie > massime) massime = cluster.corsie;
  }
  return massime;
}
