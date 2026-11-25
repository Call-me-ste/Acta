import '../core/database/database_service.dart';

/// I dati di **stress**: un giorno con 300 eventi e duemila todo in un anno.
///
/// Perche' esiste, visto che ci sono gia' i dati di prova "da studente"
/// (`demo_data.dart`): quelli sono **realistici**, questi sono **cattivi**. Le
/// liste grandi e le giornate impossibili sono il caso che nella vita vera
/// arriva dopo mesi d'uso — duemila todo accumulati, un giorno con trecento
/// impegni — e sono esattamente il caso in cui un'app che sembrava fluida
/// scatta o non si apre.
///
/// Tutto quello che scrive ha id con prefisso [idPrefix], quindi [remove] toglie
/// **esattamente** quello che [load] ha messo. Non passa dall'outbox: e' materiale
/// da laboratorio, non un dato da sincronizzare (come i dati di prova).
class StressData {
  const StressData._();

  static const String idPrefix = 'stress-';

  static const int eventi = 300;
  static const int todo = 2000;
  static const int serieRicorrenti = 50;

  /// Carica tutto in **una transazione sola** (duemila righe: transazione per
  /// riga sarebbe lentissimo) e in modo idempotente.
  static Future<int> load(DatabaseService db, {DateTime? from}) async {
    final oggi = _giorno(from ?? DateTime.now());
    var scritti = 0;

    // Idempotente: prima si toglie quello che c'era (come i dati di prova).
    remove(db);

    db.runInTransaction(() {
      // 300 eventi **nello stesso giorno**, sovrapposti a gruppi: e' il caso
      // peggiore per la griglia delle ore (i cluster, il cap a due caselle, il
      // bollino «+N») e per il foglio del cluster.
      for (var i = 0; i < eventi; i++) {
        final ora = 7 + (i % 12);
        final minuti = (i % 4) * 15;
        final durata = 30 + (i % 5) * 30;
        final inizio = DateTime(oggi.year, oggi.month, oggi.day, ora, minuti);
        db.insertEvent({
          'id': '${idPrefix}evento-$i',
          'title': 'Impegno di stress ${i + 1}',
          'description': 'Carico di prova',
          'start_time': inizio.millisecondsSinceEpoch,
          'end_time':
              inizio.add(Duration(minutes: durata)).millisecondsSinceEpoch,
          'all_day': i % 37 == 0 ? 1 : 0,
          'color_index': i % 8,
          'location': 'Sala ${1 + i % 6}',
          'version': 1,
          'updated_at': oggi.millisecondsSinceEpoch,
        });
        scritti++;
      }

      // Cinquanta serie ricorrenti: l'espansione delle ricorrenze su un anno e'
      // un lavoro che si paga a ogni finestra, e va provato con qualcosa dentro.
      for (var i = 0; i < serieRicorrenti; i++) {
        final inizio = DateTime(oggi.year, oggi.month, oggi.day, 18 + i % 4);
        db.insertEvent({
          'id': '${idPrefix}serie-$i',
          'title': 'Serie di stress ${i + 1}',
          'start_time': inizio.millisecondsSinceEpoch,
          'end_time':
              inizio.add(const Duration(hours: 2)).millisecondsSinceEpoch,
          'recurrence_rule':
              'FREQ=${i % 3 == 0 ? 'DAILY' : 'WEEKLY'};INTERVAL=1',
          'color_index': i % 8,
          'version': 1,
          'updated_at': oggi.millisecondsSinceEpoch,
        });
        scritti++;
      }

      // Duemila todo su un anno: meta' in ritardo (la fascia degli scaduti si
      // riempie), qualcuno fatto, qualcuno con l'orario, qualcuno ricorrente.
      for (var i = 0; i < todo; i++) {
        final giorno = oggi.add(Duration(days: (i % 365) - 150));
        db.insertTodo({
          'id': '${idPrefix}todo-$i',
          'title': 'To do di stress ${i + 1}',
          'completed': i % 5 == 0 ? 1 : 0,
          'priority': i % 4,
          'due_date': i % 11 == 0
              ? null
              : DateTime(giorno.year, giorno.month, giorno.day)
                  .millisecondsSinceEpoch,
          'start_time': i % 4 == 0 ? (8 + i % 10) * 60 : null,
          'end_time': i % 4 == 0 ? (9 + i % 10) * 60 : null,
          'recurrence_rule': i % 40 == 0 ? 'FREQ=WEEKLY;INTERVAL=1' : '',
          'color_index': i % 8,
          'note': i % 7 == 0 ? 'Nota del carico di prova' : '',
          'version': 1,
          'updated_at': oggi.millisecondsSinceEpoch,
        });
        scritti++;
      }
    });

    return scritti;
  }

  /// Toglie **solo** i dati di stress (gli id hanno tutti lo stesso prefisso).
  static int remove(DatabaseService db) {
    var tolti = 0;
    db.runInTransaction(() {
      for (final tabella in ['events', 'todos']) {
        final prima = _conta(db, tabella);
        db.instance.execute("DELETE FROM $tabella WHERE id LIKE '$idPrefix%'");
        tolti += prima - _conta(db, tabella);
      }
    });
    return tolti;
  }

  static int _conta(DatabaseService db, String tabella) =>
      db.instance.select('SELECT COUNT(*) AS n FROM $tabella').first['n']
          as int;

  static DateTime _giorno(DateTime valore) =>
      DateTime(valore.year, valore.month, valore.day);
}
