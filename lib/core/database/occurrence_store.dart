import 'package:sqlite3/sqlite3.dart';

/// Le eccezioni per singola occorrenza: "questo giorno l'ho fatto" / "saltato".
///
/// Vivono in una tabella a parte e non in JSON dentro l'item: così si leggono
/// con una query, non fanno crescere la riga dell'item, e soprattutto entrano
/// nel sync come una famiglia di entità normale.
class OccurrenceStore {
  OccurrenceStore(this._db);

  final Database _db;

  /// Chiave di un'occorrenza: la stessa usata come `id` della riga, così il
  /// sync generico la tratta come qualsiasi altra entità.
  static String keyFor(String itemId, DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '$itemId@${day.year.toString().padLeft(4, '0')}-$month-$dayOfMonth';
  }

  static int dayMillis(DateTime day) =>
      DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;

  /// Le date già segnate per un item (in millisecondi di inizio giornata).
  Set<int> markedDays(String itemId) {
    return _db
        .select(
          'SELECT occurrence_date FROM occurrence_overrides WHERE item_id = ?',
          [itemId],
        )
        .map((row) => row['occurrence_date'] as int)
        .toSet();
  }

  bool isDone(String itemId, DateTime day) {
    final rows = _db.select(
      "SELECT 1 FROM occurrence_overrides WHERE id = ? AND state = 'done'",
      [keyFor(itemId, day)],
    );
    return rows.isNotEmpty;
  }

  /// Tutte le occorrenze segnate «fatte», raggruppate per item: **una query**
  /// invece di una per (item, giorno).
  ///
  /// È quello che serve a disegnare un mese: la griglia chiede i todo di 44
  /// giorni, e senza questa lettura unica erano centinaia di SELECT — misurato:
  /// 337 ms per un archivio normale, contro i pochi millisecondi che dovrebbe
  /// costare.
  Map<String, Set<int>> doneDaysByItem() {
    final result = <String, Set<int>>{};
    final rows = _db.select(
      'SELECT item_id, occurrence_date FROM occurrence_overrides '
      'WHERE state = ?',
      ['done'],
    );
    for (final row in rows) {
      final itemId = row['item_id'] as String;
      (result[itemId] ??= <int>{}).add(row['occurrence_date'] as int);
    }
    return result;
  }

  /// La versione corrente dell'eccezione, per farla avanzare come per le altre
  /// entità (è il clock che il sync confronta).
  int currentVersion(String itemId, DateTime day) {
    final rows = _db.select(
      'SELECT version FROM occurrence_overrides WHERE id = ?',
      [keyFor(itemId, day)],
    );
    return rows.isEmpty ? 0 : (rows.first['version'] as int?) ?? 0;
  }
}
