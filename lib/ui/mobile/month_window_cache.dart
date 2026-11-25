import '../../features/calendar/month_window.dart';
import '../../features/events/event_provider.dart';
import '../../features/filters/filtro_condiviso.dart';
import '../../features/todos/todo_provider.dart';
import 'month_cache.dart';

/// Le finestre del mese **già calcolate**, per mese.
///
/// Perché serve: `MonthWindow.of` costruisce mappe nuove a ogni chiamata, e la
/// griglia lo chiede a ogni ricostruzione. Con cinque pagine pronte (due mesi per
/// lato) e le due chiamate che prima servivano a ognuna, uno scorrimento faceva
/// **nove finestre per fotogramma**: misurato sul telefono, 8 ms di build per
/// fotogramma mentre il dito scorreva.
///
/// La memoria (tetto, firma, sfratto *least recently used*) è `CachePerMese`, la
/// stessa delle celle: qui c'è solo **di cosa è fatta la firma**.
class FinestreDeiMesi {
  final CachePerMese<MonthWindow> _memoria = CachePerMese();

  /// La finestra di [mese], ricordata se i dati e il giorno scelto non sono
  /// cambiati.
  MonthWindow di({
    required DateTime mese,
    required EventProvider eventi,
    required TodoProvider todo,
    required DateTime selezione,
    required FiltroCondiviso filtro,
  }) =>
      _memoria.di(
        mese: mese,
        // La firma: la **generazione** dei due provider (sale a ogni scrittura), il
        // giorno scelto (la finestra porta con sé i todo e gli eventi di quel
        // giorno) e la **firma del filtro** — senza, togliere un filtro
        // restituirebbe la finestra filtrata di prima.
        firma: (
          eventi.generazione * 1000003 ^ todo.generazione,
          selezione.year * 10000 + selezione.month * 100 + selezione.day,
          filtro.firma,
        ),
        prepara: () => MonthWindow.of(
          events: eventi,
          todos: todo,
          focusedDay: mese,
          selectedDay: selezione,
          filtro: filtro,
        ),
      );
}
