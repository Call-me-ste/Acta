/// Il **pacchetto** che il renderer Kotlin legge: un giorno (righe, conteggi,
/// frasi) e il tema (i colori dei due temi di sistema).
///
/// Niente Material qui: sono dati, si serializzano in JSON e si provano senza
/// schermo (`test/features/widgets/widget_snapshot_test.dart`). I colori sono
/// **stringhe** `#rrggbb` già risolte da chi costruisce il pacchetto — il Kotlin
/// non sa cosa sia una palette, e non deve saperlo.
library;

import '../widget_contract.dart';

/// I due tipi di riga, come viaggiano nel JSON. Il widget degli eventi e quello
/// dei todo filtrano su questo.
const String tipoEvento = 'evento';
const String tipoTodo = 'todo';

/// Che giornata è: decide cosa mostra il widget **al posto** delle righe.
///
/// * `vuoto` — non c'è niente, né eventi né todo: «Niente in programma per oggi.»
/// * `tuttoFatto` — c'erano cose e sono tutte fatte: «Nient'altro in programma
///   per oggi.» (e sotto, se c'è spazio, restano quelle fatte, per poter togliere
///   una spunta sbagliata);
/// * `ok` — c'è ancora qualcosa da fare.
///
/// Gli **scaduti non contano**: il widget guarda il giorno, non l'arretrato. Il
/// foglio degli scaduti è un'altra cosa e sta nell'app.
enum StatoDelGiorno { ok, vuoto, tuttoFatto }

/// Che giornata è, **solo dai conteggi**: così la ricalcola anche il callback di
/// sfondo, che ha in mano il pacchetto e non il database.
///
/// Le tre regole:
///
/// 1. niente da nessun tipo → `vuoto`;
/// 2. un giorno con **solo todo**, tutti fatti → `tuttoFatto`;
/// 3. altrimenti → `ok`.
///
/// Gli eventi non contano come «da fare» (non si spuntano, né nell'app né qui),
/// ma **tengono la giornata aperta**: un giorno con un evento e tutti i todo
/// fatti non è «nient'altro in programma» — l'evento era in programma. La regola
/// non guarda l'ora, apposta: «adesso» cambia mentre il widget sta fermo, e un
/// widget che si contraddice da solo è peggio di un widget un po' severo.
StatoDelGiorno statoDelGiorno({
  required int eventi,
  required int todo,
  required int todoFatti,
}) {
  if (eventi == 0 && todo == 0) return StatoDelGiorno.vuoto;
  if (eventi == 0 && todo > 0 && todoFatti == todo) {
    return StatoDelGiorno.tuttoFatto;
  }
  return StatoDelGiorno.ok;
}

/// Una riga del widget: quello che si legge, e cosa succede toccandola.
class WidgetRow {
  const WidgetRow({
    required this.id,
    required this.tipo,
    required this.titolo,
    required this.ora,
    required this.colore,
    required this.coloreScuro,
    this.tuttoIlGiorno = false,
    this.fatto = false,
    this.emoji = '',
    this.inCorso = false,
  });

  /// L'id dell'elemento: è quello che torna indietro nell'URI del tocco.
  final String id;

  /// [tipoEvento] o [tipoTodo].
  final String tipo;

  final String titolo;

  /// `14:30`, oppure vuoto per chi un'ora non ce l'ha.
  final String ora;

  /// `#rrggbb`: il colore dell'elemento per il **tema chiaro**, già risolto.
  final String colore;

  /// Lo stesso colore per il **tema scuro**: sono due tinte diverse, non una
  /// schiarita a caso (una tinta piena su fondo nero sparisce), e il Kotlin
  /// sceglie in base al tema di sistema.
  final String coloreScuro;

  /// Vero per gli eventi «tutto il giorno» e per i todo senza orario.
  final bool tuttoIlGiorno;

  /// Vero **solo** per un todo fatto: gli eventi non si spuntano.
  final bool fatto;

  /// L'emoji della prima categoria dell'elemento, vuota se non ne ha: è il segno
  /// che si vede a sinistra, al posto del pallino colorato.
  final String emoji;

  /// Vero per l'elemento **in corso adesso** (solo per oggi, solo con orario):
  /// il widget lo evidenzia.
  final bool inCorso;

  bool get isTodo => tipo == tipoTodo;

  /// La stessa riga con un campo cambiato: la usa il callback di sfondo per
  /// mettere o togliere la spunta senza ricostruire colori ed emoji (che una
  /// spunta non cambia).
  WidgetRow copyWith({bool? fatto}) => WidgetRow(
        id: id,
        tipo: tipo,
        titolo: titolo,
        ora: ora,
        colore: colore,
        coloreScuro: coloreScuro,
        tuttoIlGiorno: tuttoIlGiorno,
        fatto: fatto ?? this.fatto,
        emoji: emoji,
        inCorso: inCorso,
      );

  /// Il verso di [toJson]: lo legge il callback di sfondo, che riprende la
  /// giornata pubblicata, cambia la spunta e la riscrive (senza colore e senza
  /// palette: quelle non cambiano toccando una spunta).
  factory WidgetRow.fromJson(Map<String, Object?> json) => WidgetRow(
        id: json['id'] as String? ?? '',
        tipo: json['tipo'] as String? ?? tipoEvento,
        titolo: json['titolo'] as String? ?? '',
        ora: json['ora'] as String? ?? '',
        colore: json['colore'] as String? ?? '',
        coloreScuro: json['coloreScuro'] as String? ?? '',
        tuttoIlGiorno: json['tuttoIlGiorno'] as bool? ?? false,
        fatto: json['fatto'] as bool? ?? false,
        emoji: json['emoji'] as String? ?? '',
        inCorso: json['inCorso'] as bool? ?? false,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'tipo': tipo,
        'titolo': titolo,
        'ora': ora,
        'colore': colore,
        'coloreScuro': coloreScuro,
        'tuttoIlGiorno': tuttoIlGiorno,
        'fatto': fatto,
        'emoji': emoji,
        'inCorso': inCorso,
      };
}

/// Il giorno pronto per il widget: le righe (al massimo [righeNelPacchetto], le
/// altre si contano), i conteggi **veri** e le frasi da mostrare.
class WidgetGiorno {
  const WidgetGiorno({
    required this.data,
    required this.etichetta,
    required this.stato,
    required this.righe,
    required this.eventi,
    required this.todo,
    required this.todoFatti,
    this.fraseVuoto = testoVuoto,
    this.fraseTuttoFatto = testoTuttoFatto,
  });

  final DateTime data;

  /// L'intestazione: `Oggi · gio 24 set`, oppure `gio 24 set`.
  final String etichetta;

  final StatoDelGiorno stato;

  final List<WidgetRow> righe;

  /// Quanti eventi e quanti todo ha la giornata **davvero**: le righe sono
  /// tagliate a [righeNelPacchetto], i conteggi no. Senza questi, «+N altri»
  /// conterebbe solo quello che è arrivato.
  final int eventi;
  final int todo;
  final int todoFatti;

  /// Le due frasi degli stati vuoti, **dentro il pacchetto**: viaggiano fino al
  /// renderer (che le stampa e basta) così la voce dell'app resta in un posto
  /// solo, e si prova in Dart.
  final String fraseVuoto;
  final String fraseTuttoFatto;

  /// Quanti todo restano da fare: è il numero della barretta di avanzamento.
  int get todoDaFare => todo - todoFatti;

  factory WidgetGiorno.fromJson(Map<String, Object?> json) {
    final righe = json['righe'] as List? ?? const [];
    return WidgetGiorno(
      data: DateTime.parse(json['data'] as String),
      etichetta: json['etichetta'] as String? ?? '',
      stato: StatoDelGiorno.values.firstWhere(
        (valore) => valore.name == json['stato'],
        orElse: () => StatoDelGiorno.ok,
      ),
      righe: [
        for (final riga in righe)
          WidgetRow.fromJson((riga as Map).cast<String, Object?>()),
      ],
      eventi: json['eventi'] as int? ?? 0,
      todo: json['todo'] as int? ?? 0,
      todoFatti: json['todoFatti'] as int? ?? 0,
      fraseVuoto: json['fraseVuoto'] as String? ?? testoVuoto,
      fraseTuttoFatto: json['fraseTuttoFatto'] as String? ?? testoTuttoFatto,
    );
  }

  Map<String, Object?> toJson() => {
        'data': dataIso(data),
        'etichetta': etichetta,
        'stato': stato.name,
        'righe': [for (final riga in righe) riga.toJson()],
        'eventi': eventi,
        'todo': todo,
        'todoFatti': todoFatti,
        'fraseVuoto': fraseVuoto,
        'fraseTuttoFatto': fraseTuttoFatto,
      };
}

/// I colori dei **due** temi di sistema, con i nomi dei ruoli.
///
/// Due e non uno perché il widget vive sulla schermata home: lì decide il sistema
/// (chiaroscuro), non la scelta fatta dentro l'app. I **colori** però sono quelli
/// della palette attiva, così il widget e l'app si somigliano.
class WidgetTema {
  const WidgetTema({required this.chiaro, required this.scuro});

  final Map<String, String> chiaro;
  final Map<String, String> scuro;

  Map<String, Object?> toJson() => {'light': chiaro, 'dark': scuro};
}
