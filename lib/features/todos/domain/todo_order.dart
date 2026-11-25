import 'todo.dart';

/// L'ordine con cui si mostrano i todo: prima chi ha un **orario** (crescente),
/// poi chi non ce l'ha; dentro ogni gruppo i piu' urgenti, poi i piu' vecchi.
///
/// «Alle 8» e' piu' urgente di «oggi, senza orario»: e' la regola richiesta
/// dall'utente, ed e' quella che rende leggibile un elenco di cose da fare.
///
/// Sta fuori dal provider per due ragioni: il file del provider ha un tetto di
/// righe, e questa e' una **funzione pura** — si prova senza database e senza
/// costruire un provider.
int confrontaTodo(Todo a, Todo b) {
  final quandoA = a.firstTime;
  final quandoB = b.firstTime;
  if ((quandoA == null) != (quandoB == null)) {
    return quandoA == null ? 1 : -1;
  }
  if (quandoA != null && quandoB != null && quandoA != quandoB) {
    return quandoA.compareTo(quandoB);
  }
  final perPriorita = b.priority.compareTo(a.priority);
  if (perPriorita != 0) return perPriorita;
  final millisA = a.updatedAt?.millisecondsSinceEpoch ?? 0;
  final millisB = b.updatedAt?.millisecondsSinceEpoch ?? 0;
  return millisA.compareTo(millisB);
}
