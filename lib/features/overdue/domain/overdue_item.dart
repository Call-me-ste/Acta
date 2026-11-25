/// Un elemento passato che aspetta una conferma: «è stato fatto?».
///
/// Vive fuori dai due domini perché la domanda è la stessa per eventi e todo:
/// il foglio delle conferme mostra un elenco solo, ordinato dal più vecchio.
class OverdueItem {
  const OverdueItem({
    required this.id,
    required this.title,
    required this.date,
    required this.isEvent,
  });

  /// L'id dell'evento o del todo (la serie, non l'occorrenza).
  final String id;

  final String title;

  /// Il giorno dell'occorrenza (o della scadenza), a mezzanotte.
  final DateTime date;

  /// Serve a sapere **dove** scrivere la conferma: eventi e todo hanno
  /// provider diversi, la tabella delle occorrenze è la stessa.
  final bool isEvent;
}

/// Eventi e todo in un elenco solo, dal più vecchio: si conferma a partire da
/// quello che aspetta da più tempo.
List<OverdueItem> sortedOverdue(
  List<OverdueItem> events,
  List<OverdueItem> todos,
) {
  return [...events, ...todos]..sort((a, b) => a.date.compareTo(b.date));
}
