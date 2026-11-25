/// Il **pacchetto del mese**: la griglia che disegna il widget mensile, con il
/// conteggio vero degli eventi e poche anteprime per giorno.
///
/// Sta in un file suo e non dentro `widget_payload.dart` per la stessa ragione
/// per cui il mese è un pacchetto separato: i tre widget della giornata non
/// devono portarsi dietro 42 giorni, e il mese non deve portarsi dietro le loro
/// righe. Il renderer Kotlin legge i due pacchetti da chiavi diverse.
library;

/// Un'anteprima di evento dentro una cella del mese: il titolo e il colore nei
/// **due** temi (chiaro e scuro), già risolti da Dart.
///
/// Poche e non tutte: in una cella di un widget ci stanno due titoli, e quelli
/// che non ci stanno si contano (`eventi` nel giorno). Il titolo può essere
/// vuoto se l'evento non ne ha uno: la cella mostra allora solo il colore.
class WidgetMeseAnteprima {
  const WidgetMeseAnteprima({
    required this.titolo,
    required this.colore,
    required this.coloreScuro,
  });

  final String titolo;

  /// `#rrggbb` per il tema chiaro e per quello scuro, come nelle righe dei
  /// widget della giornata.
  final String colore;
  final String coloreScuro;

  factory WidgetMeseAnteprima.fromJson(Map<String, Object?> json) =>
      WidgetMeseAnteprima(
        titolo: json['titolo'] as String? ?? '',
        colore: json['colore'] as String? ?? '',
        coloreScuro: json['coloreScuro'] as String? ?? '',
      );

  Map<String, Object?> toJson() => {
        'titolo': titolo,
        'colore': colore,
        'coloreScuro': coloreScuro,
      };
}

/// Un giorno della griglia: il numero, se è del mese mostrato o di uno
/// adiacente, quante cose ci sono **davvero** e le poche anteprime che ci
/// stanno.
class WidgetMeseGiorno {
  const WidgetMeseGiorno({
    required this.data,
    required this.giorno,
    required this.fuoriMese,
    required this.eventi,
    this.anteprime = const [],
    this.oggi = false,
  });

  /// `2026-09-24`: la stessa forma delle chiavi e degli URI.
  final String data;

  /// Il numero da stampare nella cella (`1`…`31`).
  final int giorno;

  /// Vero per i giorni dei mesi adiacenti che completano la prima e l'ultima
  /// settimana: si vedono attenuati, e toccarli cambia mese.
  final bool fuoriMese;

  /// Quanti eventi ha la giornata **davvero**: le anteprime sono tagliate a
  /// [anteprimeNelMese], questo numero no. Senza, «+N» mentirebbe.
  final int eventi;

  final List<WidgetMeseAnteprima> anteprime;

  /// Vero per il giorno di oggi: la cella lo segna, come nel calendario
  /// dell'app.
  final bool oggi;

  /// Quante anteprime **non** sono nel pacchetto: è il «+N» della cella.
  int get altre => (eventi - anteprime.length).clamp(0, eventi);

  factory WidgetMeseGiorno.fromJson(Map<String, Object?> json) {
    final anteprime = json['anteprime'] as List? ?? const [];
    return WidgetMeseGiorno(
      data: json['data'] as String? ?? '',
      giorno: json['giorno'] as int? ?? 0,
      fuoriMese: json['fuoriMese'] as bool? ?? false,
      eventi: json['eventi'] as int? ?? 0,
      anteprime: [
        for (final voce in anteprime)
          WidgetMeseAnteprima.fromJson((voce as Map).cast<String, Object?>()),
      ],
      oggi: json['oggi'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
        'data': data,
        'giorno': giorno,
        'fuoriMese': fuoriMese,
        'eventi': eventi,
        'anteprime': [for (final voce in anteprime) voce.toJson()],
        'oggi': oggi,
      };
}

/// Un mese pronto per il widget: la griglia intera (settimane × 7 giorni) e
/// l'intestazione.
class WidgetMese {
  const WidgetMese({
    required this.anno,
    required this.mese,
    required this.etichetta,
    required this.settimane,
    required this.giorni,
  });

  final int anno;

  /// 1…12.
  final int mese;

  /// L'intestazione: `settembre 2026`.
  final String etichetta;

  /// Quante righe ha la griglia: **4**, 5 o 6. È il numero che decide quante
  /// righe il renderer deve disegnare — e quindi quante ne può nascondere
  /// quando l'altezza non basta.
  final int settimane;

  /// `settimane × 7` giorni, in ordine: prima i giorni del mese precedente che
  /// completano la settimana del primo, poi il mese, poi quelli del successivo.
  final List<WidgetMeseGiorno> giorni;

  /// Il primo del mese: è la chiave con cui viaggia il pacchetto
  /// (`widget_mese_2026-09`), come per i giorni è la loro data.
  DateTime get data => DateTime(anno, mese);

  factory WidgetMese.fromJson(Map<String, Object?> json) {
    final giorni = json['giorni'] as List? ?? const [];
    return WidgetMese(
      anno: json['anno'] as int? ?? 0,
      mese: json['mese'] as int? ?? 0,
      etichetta: json['etichetta'] as String? ?? '',
      settimane: json['settimane'] as int? ?? 0,
      giorni: [
        for (final giorno in giorni)
          WidgetMeseGiorno.fromJson((giorno as Map).cast<String, Object?>()),
      ],
    );
  }

  Map<String, Object?> toJson() => {
        'anno': anno,
        'mese': mese,
        'etichetta': etichetta,
        'settimane': settimane,
        'giorni': [for (final giorno in giorni) giorno.toJson()],
      };
}
