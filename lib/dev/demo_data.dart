import '../core/database/database_service.dart';
import 'prova_notifiche.dart';

/// Dati di prova: l'agenda di uno **studente universitario**, piena come nella
/// vita vera — lezioni che tornano ogni settimana, sport, esami, commissioni,
/// spesa, scadenze — in un volume che serve a stressare l'app (150 todo, 45
/// eventi singoli e 6 serie ricorrenti).
///
/// Perche' esiste: gli scatti si vedono solo con i dati dentro, e "proviamo con
/// due elementi" non misura niente. Tutto quello che scrive ha id con prefisso
/// [idPrefix], quindi [remove] toglie **esattamente** quello che [load] ha
/// messo e non tocca un solo dato vero.
///
/// Il file e' isolato di proposito: per togliere la funzione si cancella questo
/// file, `ui/mobile/demo_section.dart` e le due righe che lo chiamano.
class DemoData {
  const DemoData._();

  static const String idPrefix = 'demo-';

  /// Quanti elementi carica: il numero è anche quello che mostra il comando.
  static const int todos = 150;
  static const int events = 45;
  static const int series = 6;
  static const int recurringTodos = 8;

  /// Categorie di uno studente: studio, casa, sport, lavoro, personale.
  static const List<(String, String, String)> _categorie = [
    ('Universita\'', '🎓', '#7E57C2'),
    ('Casa', '🏠', '#4CAF50'),
    ('Sport', '🏃', '#00BCD4'),
    ('Lavoro', '💼', '#FF9800'),
    ('Personale', '❤️', '#E91E63'),
  ];

  /// Le lezioni della settimana, come serie ricorrenti (`BYDAY` della regola).
  static const List<(String, String, String, int, int, int)> _lezioni = [
    ('Analisi Matematica', 'Aula 3', 'FREQ=WEEKLY;BYDAY=MO,WE,FR', 9, 11, 0),
    ('Fisica Generale', 'Laboratorio 2', 'FREQ=WEEKLY;BYDAY=TU,TH', 11, 13, 1),
    ('Programmazione', 'Aula 7', 'FREQ=WEEKLY;BYDAY=MO,WE', 14, 16, 2),
    ('Storia Contemporanea', 'Aula Magna', 'FREQ=WEEKLY;BYDAY=FR', 16, 18, 3),
    ('Palestra', 'Centro sportivo', 'FREQ=WEEKLY;BYDAY=TU,TH', 18, 20, 2),
    ('Volontariato', 'Casa del quartiere', 'FREQ=WEEKLY;BYDAY=SA', 10, 12, 4),
  ];

  /// Cose di casa che tornano.
  static const List<(String, String, String)> _ricorrenti = [
    ('Spesa settimanale', 'FREQ=WEEKLY;BYDAY=SA', 'Casa'),
    ('Pulizie di casa', 'FREQ=WEEKLY;BYDAY=SA', 'Casa'),
    ('Bolletta luce', 'FREQ=MONTHLY;BYMONTHDAY=15', 'Casa'),
    ('Ripasso settimanale', 'FREQ=WEEKLY;BYDAY=SU', 'Universita\''),
    ('Palestra: iscrizione mensile', 'FREQ=MONTHLY;BYMONTHDAY=1', 'Sport'),
    ('Bucato', 'FREQ=WEEKLY;BYDAY=WE', 'Casa'),
    ('Turno in biblioteca', 'FREQ=WEEKLY;BYDAY=TH', 'Lavoro'),
    ('Aggiornare il budget', 'FREQ=WEEKLY;BYDAY=SU', 'Personale'),
  ];

  /// Impegni singoli: fra lezioni, uscite e scadenze.
  static const List<(String, String, int, int)> _impegni = [
    ('Esame di Analisi', 'Aula 3', 9, 12),
    ('Consegna progetto di Programmazione', 'On line', 23, 23),
    ('Cinema con Marta', 'Multisala', 21, 23),
    ('Compleanno di Luca', 'Casa di Luca', 20, 23),
    ('Visita dal medico', 'Studio dott. Rossi', 15, 16),
    ('Biblioteca: prestito libri', 'Biblioteca centrale', 10, 12),
    ('Colloquio tirocinio', 'Palazzo B', 14, 15),
    ('Pranzo dai genitori', 'Casa', 13, 15),
    ('Ripetizioni di matematica', 'On line', 17, 18),
    ('Partita a calcetto', 'Campo comunale', 19, 21),
    ('Registrazione esame', 'Portale studenti', 8, 9),
    ('Consegna relazione di Fisica', 'On line', 18, 19),
    ('Assemblea studenti', 'Aula Magna', 12, 14),
    ('Concerto', 'Teatro', 21, 24),
    ('Gita a Firenze', 'Stazione', 7, 22),
  ];

  /// Le cose da fare: studio, casa, commissioni.
  static const List<String> _todoStudio = [
    'Ripassare Analisi - capitolo',
    'Esercizi di Fisica - serie',
    'Laboratorio di Programmazione - consegna',
    'Rileggere appunti di Storia - unita\'',
    'Preparare domande per il ricevimento',
    'Riassunto del capitolo',
    'Mappa concettuale di Analisi',
    'Ripasso formule di Fisica',
    'Sistemare gli appunti di',
    'Simulazione esame di',
  ];

  static const List<String> _todoCasa = [
    'Fare la spesa',
    'Lavare i piatti',
    'Stendere il bucato',
    'Passare l\'aspirapolvere',
    'Cambiare le lenzuola',
    'Portare la spazzatura',
    'Riordinare la scrivania',
    'Annacquare le piante',
    'Riparare la lampada',
    'Pulire il bagno',
  ];

  static const List<String> _todoFuori = [
    'Ritirare il pacco',
    'Pagare l\'affitto',
    'Ricaricare la tessera dei mezzi',
    'Fare la fila in segreteria',
    'Comprare il regalo per',
    'Prenotare il treno per casa',
    'Ritirare le analisi',
    'Restituire i libri in biblioteca',
    'Rinnovare l\'abbonamento',
    'Passare in posta',
  ];

  /// Carica tutto in **una transazione sola**: e' un dato di prova, non si
  /// sincronizza (fuori dall'outbox) e non deve metterci piu' di un istante.
  /// E' idempotente: prima toglie quello che c'era.
  static Future<int> load(DatabaseService db, {DateTime? from}) async {
    final oggi = _dayOnly(from ?? DateTime.now());
    var scritti = 0;

    remove(db);

    db.runInTransaction(() {
      for (var i = 0; i < _categorie.length; i++) {
        final (nome, emoji, colore) = _categorie[i];
        db.categories.upsert({
          'id': '${idPrefix}cat-$i',
          'name': nome,
          'emoji': emoji,
          'color_hex': colore,
          'version': 1,
          'updated_at': oggi.millisecondsSinceEpoch,
        });
        scritti++;
      }

      // Le serie ricorrenti: una riga per lezione, ripetuta dalla regola.
      for (var i = 0; i < _lezioni.length; i++) {
        final (titolo, luogo, regola, da, a, categoria) = _lezioni[i];
        final inizio = _giornoDaOggi(oggi, -60);
        db.insertEvent({
          'id': '${idPrefix}serie-$i',
          'title': titolo,
          'description': 'Lezione',
          'start_time': _at(inizio, da).millisecondsSinceEpoch,
          'end_time': _at(inizio, a).millisecondsSinceEpoch,
          'color_index': i,
          'recurrence_rule': regola,
          'location': luogo,
          'category_ids': '${idPrefix}cat-0',
          'version': 1,
          'updated_at': oggi.millisecondsSinceEpoch,
        });
        scritti++;
      }

      // Impegni singoli, sparsi attorno a oggi (meta' passati, meta' futuri).
      for (var i = 0; i < events; i++) {
        final (titolo, luogo, da, a) = _impegni[i % _impegni.length];
        final giorno = _giornoDaOggi(oggi, (i * 3) - 30);
        final tutto = i % 11 == 0;
        db.insertEvent({
          'id': '${idPrefix}evento-$i',
          'title':
              '$titolo${i >= _impegni.length ? ' (${1 + i ~/ _impegni.length})' : ''}',
          'start_time': _at(giorno, da).millisecondsSinceEpoch,
          'end_time': _at(giorno, a).millisecondsSinceEpoch,
          'all_day': tutto ? 1 : 0,
          'color_index': i % 10,
          'category_ids': '${idPrefix}cat-${i % _categorie.length}',
          'location': luogo,
          'version': 1,
          'updated_at': oggi.millisecondsSinceEpoch,
        });
        scritti++;
      }

      // Due eventi per provare le notifiche sul telefono (fra due e quattro
      // minuti, con un minuto di anticipo): stanno in un file loro perché questo
      // è già al tetto delle righe.
      scritti += ProvaNotifiche.carica(db, idPrefix: idPrefix);

      for (var i = 0; i < recurringTodos; i++) {
        final (titolo, regola, categoria) = _ricorrenti[i % _ricorrenti.length];
        final giorno = _giornoDaOggi(oggi, -(i % 5));
        db.insertTodo({
          'id': '${idPrefix}ricorrente-$i',
          'title': titolo,
          'priority': i % 3,
          'due_date': giorno.millisecondsSinceEpoch,
          'category_ids': _categoriaId(categoria),
          'recurrence_rule': regola,
          'color_index': i % 10,
          'version': 1,
          'updated_at': oggi.millisecondsSinceEpoch,
        });
        scritti++;
      }

      // I todo del quotidiano: studio, casa, commissioni, sparsi su un mese e
      // mezzo, con priorita' e scadenze diverse come nella vita vera.
      for (var i = 0; i < todos; i++) {
        final gruppo = i % 3;
        final titolo = switch (gruppo) {
          0 => '${_todoStudio[i % _todoStudio.length]} ${1 + i % 12}',
          1 => _todoCasa[i % _todoCasa.length],
          _ =>
            '${_todoFuori[i % _todoFuori.length]} ${i % 4 == 0 ? 'mamma' : 'nonna'}',
        };
        final giorno = _giornoDaOggi(oggi, (i % 45) - 15);
        db.insertTodo({
          'id': '${idPrefix}todo-$i',
          'title': titolo,
          'completed': i % 7 == 0 ? 1 : 0,
          'priority': i % 4,
          'due_date': i % 13 == 0 ? null : giorno.millisecondsSinceEpoch,
          // Un terzo dei todo ha anche un'ora, con la sua durata: cosi' i dati di
          // prova coprono anche i todo **con orario** — quelli che in «Pieni»
          // entrano nella griglia delle ore. Senza, quella parte non si vedeva
          // mai (e una verifica sul telefono non poteva mostrarla).
          'start_time': i % 3 == 0 ? (8 + i % 6) * 60 : null,
          'end_time': i % 3 == 0 ? (9 + i % 6) * 60 : null,
          'category_ids': _categoriaId(
            switch (gruppo) {
              0 => 'Universita\'',
              1 => 'Casa',
              _ => 'Personale',
            },
          ),
          'color_index': i % 10,
          'note': i % 9 == 0 ? 'Da fare con calma' : '',
          'version': 1,
          'updated_at': oggi.millisecondsSinceEpoch,
        });
        scritti++;
      }
    });

    return scritti;
  }

  /// Toglie **solo** i dati di prova: gli id hanno tutti lo stesso prefisso.
  /// Torna quante righe ha cancellato (per dirlo all'utente).
  static int remove(DatabaseService db) {
    var tolti = 0;
    db.runInTransaction(() {
      for (final tabella in ['events', 'todos', 'categories']) {
        final prima = _count(db, tabella);
        db.instance.execute(
          "DELETE FROM $tabella WHERE id LIKE '$idPrefix%'",
        );
        tolti += prima - _count(db, tabella);
      }
    });
    return tolti;
  }

  static int _count(DatabaseService db, String tabella) {
    return db.instance.select('SELECT COUNT(*) AS n FROM $tabella').first['n']
        as int;
  }

  static String _categoriaId(String nome) {
    for (var i = 0; i < _categorie.length; i++) {
      if (_categorie[i].$1 == nome) return '${idPrefix}cat-$i';
    }
    return '';
  }

  static DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _giornoDaOggi(DateTime oggi, int giorni) =>
      oggi.add(Duration(days: giorni));

  static DateTime _at(DateTime giorno, int ora) =>
      DateTime(giorno.year, giorno.month, giorno.day, ora);
}
