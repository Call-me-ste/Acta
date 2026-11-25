/// Quanti giorni mancano a una scadenza, e se e' passata.
///
/// Sta nel dominio e non nella UI perche' lo usano sia le parole che si leggono
/// ("Scaduta da 3 giorni") sia il **filtro** della scheda Todo, che deve
/// decidere senza disegnare niente, sia le finestre del calendario.
library;

/// Il giorno senza l'ora: la chiave con cui si raggruppa.
DateTime dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Quanti giorni mancano a una scadenza: negativo se e' passata, zero se e'
/// oggi.
///
/// Il conto si fa fra **giorni di calendario** (mezzanotte UTC), non fra istanti:
/// con la differenza fra `DateTime` locali, la notte del cambio d'ora un todo di
/// domani risultava di 0 giorni — "Oggi" su una cosa che e' domani.
int daysUntilDue(DateTime due, {DateTime? from}) {
  final oggi = from ?? DateTime.now();
  final a = DateTime.utc(due.year, due.month, due.day);
  final b = DateTime.utc(oggi.year, oggi.month, oggi.day);
  return a.difference(b).inDays;
}

/// Vero se la scadenza e' passata (oggi non lo e': la giornata non e' finita).
bool isOverdue(DateTime due, {DateTime? from}) =>
    daysUntilDue(due, from: from) < 0;
