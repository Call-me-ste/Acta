import '../events/domain/event_occurrence.dart';
import '../todos/domain/todo.dart';

/// Cosa si sta guardando: solo gli eventi, solo i todo, o tutti e due.
enum CosaMostrare { eventi, todo, entrambi }

/// Fin quanto in avanti si guarda.
enum Orizzonte { giorni7, giorni30, giorni90 }

/// Le parole delle scelte: stanno qui e non nell'interfaccia, come
/// `todoRangeLabels` per le viste dei todo. L'agenda e il suo foglio dei filtri
/// le leggono da qui, quindi non possono dire due cose diverse.
const Map<CosaMostrare, String> cosaMostrareLabels = {
  CosaMostrare.eventi: 'Solo eventi',
  CosaMostrare.todo: 'Solo To do',
  CosaMostrare.entrambi: 'Eventi e To do',
};

const Map<Orizzonte, String> orizzonteLabels = {
  Orizzonte.giorni7: '7 giorni',
  Orizzonte.giorni30: '30 giorni',
  Orizzonte.giorni90: '90 giorni',
};

/// La lente dell'**agenda** e del **calendario**: categorie, cosa mostrare,
/// orizzonte. Una sola, perche' le due schermate mostrano gli stessi dati e
/// chiedere due volte le stesse cose sarebbe due volte il posto in cui
/// sbagliarle.
///
/// Elenco di categorie **vuoto = nessun vincolo**, come `TodoFilter`: chi non
/// sceglie niente vede tutto. Con almeno una categoria scelta, un elemento
/// passa solo se **una delle sue** e' fra quelle scelte (quindi chi non ha
/// categorie sparisce): e' la stessa regola dei todo, e si legge in un posto
/// solo.
///
/// Il filtro dei **todo** (priorita', viste «Oggi»/«Scaduti») resta il suo,
/// nella scheda Todo: sono due domande diverse — quello dice cosa devo fare,
/// questo cosa voglio vedere — e unificarli vorrebbe dire che filtrare
/// l'agenda cambia l'elenco dei todo.
class FiltroCondiviso {
  const FiltroCondiviso({
    this.categorieScelte = const {},
    this.cosa = CosaMostrare.entrambi,
    this.orizzonte = Orizzonte.giorni30,
  });

  final Set<String> categorieScelte;
  final CosaMostrare cosa;
  final Orizzonte orizzonte;

  /// Vero quando non c'e' nessun vincolo: e' anche il filtro di partenza, ed e'
  /// il motivo per cui i golden del calendario non cambiano.
  bool get isEmpty =>
      categorieScelte.isEmpty &&
      cosa == CosaMostrare.entrambi &&
      orizzonte == Orizzonte.giorni30;

  /// Quanti giorni avanti si guarda: e' l'orizzonte, non un numero fisso.
  int get giorni => switch (orizzonte) {
        Orizzonte.giorni7 => 7,
        Orizzonte.giorni30 => 30,
        Orizzonte.giorni90 => 90,
      };

  bool get mostraEventi => cosa != CosaMostrare.todo;
  bool get mostraTodo => cosa != CosaMostrare.eventi;

  /// Vero se l'occorrenza va mostrata: il «cosa» **e** le categorie.
  ///
  /// Le due regole stanno nella stessa funzione apposta: chi disegna chiede
  /// «passa?» e non ricostruisce a mano la combinazione — che e' il modo in cui
  /// una delle due finisce dimenticata in una vista su tre.
  bool passaEvento(EventOccurrence occurrence) =>
      mostraEventi && _passaCategorie(occurrence.event.categoryIds);

  /// Come [passaEvento], per un todo.
  bool passaTodo(Todo todo) => mostraTodo && _passaCategorie(todo.categoryIds);

  bool _passaCategorie(List<String> ids) =>
      categorieScelte.isEmpty || ids.any(categorieScelte.contains);

  /// Le occorrenze che passano, in una lista **nuova**: quella che torna dal
  /// provider e' condivisa con la sua memoria, quindi non si tocca.
  List<EventOccurrence> filtraEventi(Iterable<EventOccurrence> occorrenze) => [
        for (final occurrence in occorrenze)
          if (passaEvento(occurrence)) occurrence,
      ];

  /// Come [filtraEventi], per i todo.
  List<Todo> filtraTodo(Iterable<Todo> todos) => [
        for (final todo in todos)
          if (passaTodo(todo)) todo,
      ];

  FiltroCondiviso copyWith({
    Set<String>? categorieScelte,
    CosaMostrare? cosa,
    Orizzonte? orizzonte,
  }) {
    return FiltroCondiviso(
      categorieScelte: categorieScelte ?? this.categorieScelte,
      cosa: cosa ?? this.cosa,
      orizzonte: orizzonte ?? this.orizzonte,
    );
  }

  /// La firma: una stringa che cambia **se e solo se** cambia il filtro.
  ///
  /// Serve alle memorie (le celle del mese, le finestre dei mesi, le tre viste):
  /// senza, un filtro tolto resterebbe invisibile — la memoria tiene la copia
  /// vecchia e nessuno la invalida. E' la stessa trappola della modalita' «todo
  /// nel calendario», che e' entrata nella firma per lo stesso motivo.
  String get firma => '${(categorieScelte.toList()..sort()).join(',')}'
      '|${cosa.name}|${orizzonte.name}';
}
