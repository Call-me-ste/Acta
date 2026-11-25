import 'domain/todo.dart';
import 'domain/todo_dates.dart';

/// Le **viste** della scheda Todo: cosa si sta guardando, non un filtro.
///
/// Poche di proposito, come nelle app di riferimento (Microsoft To Do, Google
/// Tasks, Apple Promemoria): le liste intelligenti sono tre o quattro, non sette,
/// e si scelgono da un menu' nell'intestazione invece che da una fila di
/// pastiglie sempre in vista.
///
/// Gli **scaduti** e i **completati** non sono viste: stanno in due fasce
/// richiudibili (sopra e sotto), cosi' restano raggiungibili da qualunque vista
/// senza rubare una voce al menu'.
enum TodoRange { tutte, oggi, oggiEDomani, prossimi7, senzaData }

/// Le parole delle viste, in un posto solo.
const Map<TodoRange, String> todoRangeLabels = {
  TodoRange.tutte: 'Tutte',
  TodoRange.oggi: 'Oggi',
  // «Oggi e domani» al posto di «Domani» (richiesta dell'utente): quello che
  // scade domani si guarda **insieme** a quello di oggi, perche' e' li' che si
  // decide cosa fare adesso.
  TodoRange.oggiEDomani: 'Oggi e domani',
  TodoRange.prossimi7: 'Prossimi 7 giorni',
  TodoRange.senzaData: 'Senza data',
};

/// Quello che si sta guardando, piu' le categorie e le priorita' scelte.
///
/// Elenco vuoto significa **nessun vincolo**, non "niente": chi non sceglie
/// niente vede tutto. E' il motivo per cui il filtro vuoto e' anche quello di
/// partenza.
class TodoFilter {
  const TodoFilter({
    this.range = TodoRange.tutte,
    this.categoryIds = const {},
    this.priorities = const {},
  });

  final TodoRange range;
  final Set<String> categoryIds;
  final Set<int> priorities;

  /// Vero quando non c'e' nessun vincolo: e' anche il filtro di partenza.
  bool get isEmpty =>
      range == TodoRange.tutte && categoryIds.isEmpty && priorities.isEmpty;

  TodoFilter copyWith({
    TodoRange? range,
    Set<String>? categoryIds,
    Set<int>? priorities,
  }) {
    return TodoFilter(
      range: range ?? this.range,
      categoryIds: categoryIds ?? this.categoryIds,
      priorities: priorities ?? this.priorities,
    );
  }

  /// Vero se il todo passa i filtri **fini** (categorie e priorita').
  ///
  /// Serve anche ai **completati**, che hanno la loro fascia e non dipendono
  /// dalla vista: la vista riguarda cosa resta da fare.
  bool passesCategoriesAndPriorities(Todo todo) {
    if (priorities.isNotEmpty && !priorities.contains(todo.priority)) {
      return false;
    }
    if (categoryIds.isNotEmpty && !todo.categoryIds.any(categoryIds.contains)) {
      return false;
    }
    return true;
  }

  /// Vero se il todo va mostrato nell'**elenco**.
  ///
  /// `done` lo decide chi conosce le occorrenze (un ricorrente ha la sua
  /// occorrenza spuntata, non un `completed`), e `today` si passa da fuori:
  /// cosi' la regola si prova senza aspettare mezzanotte.
  ///
  /// Quello che si e' spuntato **non** compare qui: ha la sua fascia in fondo.
  /// Mostrarlo in due posti era il modo piu' facile di far sembrare l'elenco
  /// disordinato.
  bool matches(Todo todo, {required bool done, required DateTime today}) {
    if (!passesCategoriesAndPriorities(todo)) return false;
    if (done) return false;

    final due = todo.dueDate;
    if (range == TodoRange.tutte) return true;
    if (range == TodoRange.senzaData) return due == null;
    if (due == null) return false;

    final giorni = daysUntilDue(due, from: today);
    return switch (range) {
      TodoRange.oggi => giorni == 0,
      TodoRange.oggiEDomani => giorni == 0 || giorni == 1,
      // Gli scaduti (giorni < 0) non sono "nei prossimi 7 giorni": hanno la loro
      // fascia.
      TodoRange.prossimi7 => giorni >= 0 && giorni <= 7,
      TodoRange.tutte || TodoRange.senzaData => true,
    };
  }
}
