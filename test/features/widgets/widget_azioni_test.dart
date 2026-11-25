import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/widgets/domain/widget_payload.dart';
import 'package:planner/features/widgets/widget_actions.dart';

import '../../support/fake_widget_bridge.dart';

/// La spunta fatta **dal widget**: la regola è quella dell'app, e il widget non
/// può fare niente di più.
///
/// Perché conta: è l'unico punto dell'app che scrive con l'app **chiusa**, in un
/// processo avviato dal sistema. Le cose da pretendere sono quattro: un todo
/// singolo si spunta e si toglie, un'occorrenza ricorrente si segna e **non** si
/// toglie (come nell'app), un id che non esiste non scrive niente, e la giornata
/// ridisegnata è coerente (riga, conteggi, stato).
void main() {
  late DatabaseService db;
  late FakeWidgetBridge ponte;
  final giorno = DateTime(2026, 9, 24);

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    ponte = FakeWidgetBridge();
  });

  tearDown(() => db.close());

  void scriviTodo(
    String id, {
    String titolo = 'Spesa',
    bool fatto = false,
    String ricorrenza = '',
    List<String> categorie = const [],
  }) {
    db.insertTodo({
      'id': id,
      'title': titolo,
      'completed': fatto ? 1 : 0,
      'priority': 0,
      'due_date': giorno.millisecondsSinceEpoch,
      'start_time': null,
      'end_time': null,
      'hidden_in_calendar': 0,
      'category_ids': categorie.join(','),
      'color_index': null,
      'recurrence_rule': ricorrenza,
      'reminder_leads': null,
      'reminder_sound': null,
      'location': '',
      'note': '',
      'version': 1,
      'updated_at': giorno.millisecondsSinceEpoch,
    });
  }

  /// La giornata **pubblicata** dal widget: è quella che il callback riprende e
  /// riscrive (colori ed emoji compresi, che non si ricalcolano).
  WidgetGiorno pubblicato({required List<WidgetRow> righe, int todo = 1}) =>
      WidgetGiorno(
        data: giorno,
        etichetta: 'Oggi · gio 24 set',
        stato: StatoDelGiorno.ok,
        righe: righe,
        eventi: 0,
        todo: todo,
        todoFatti: righe.where((riga) => riga.isTodo && riga.fatto).length,
      );

  WidgetRow riga(String id, {bool fatto = false}) => WidgetRow(
        id: id,
        tipo: tipoTodo,
        titolo: 'Spesa',
        ora: '',
        colore: '#222222',
        coloreScuro: '#222223',
        tuttoIlGiorno: true,
        fatto: fatto,
      );

  test('un todo singolo: si spunta, e il pacchetto si aggiorna', () async {
    scriviTodo('t1');
    ponte.preparaGiorno(pubblicato(righe: [riga('t1')]));

    final esito = await spuntaDalWidget(
      db: db,
      bridge: ponte,
      id: 't1',
      giorno: giorno,
    );

    expect(esito, isTrue);
    expect(db.getTodos().single['completed'], 1,
        reason: 'la spunta è scritta nel database, come farebbe l\'app');
    expect(db.outbox.pending(), hasLength(1),
        reason: 'e accodata per il sync, come ogni altra scrittura');

    final aggiornata = await ponte.leggiGiorno(giorno);
    expect(aggiornata!.righe.single.fatto, isTrue);
    expect(aggiornata.todoFatti, 1);
    expect(aggiornata.stato, StatoDelGiorno.tuttoFatto,
        reason: 'solo todo, tutti fatti: «nient\'altro in programma»');
    expect(aggiornata.righe.single.colore, '#222222',
        reason: 'i colori non si ricalcolano: non cambiano toccando una spunta');
    expect(ponte.aggiornamenti, 1);
    expect(ponte.fattoIl(), isNotNull,
        reason: 'l\'app che torna in primo piano deve sapere che il widget ha '
            'scritto');
  });

  test('un todo singolo si spunta **e si toglie**', () async {
    scriviTodo('t1', fatto: true);
    ponte.preparaGiorno(pubblicato(righe: [riga('t1', fatto: true)]));

    await spuntaDalWidget(db: db, bridge: ponte, id: 't1', giorno: giorno);

    expect(db.getTodos().single['completed'], 0);
    final aggiornata = await ponte.leggiGiorno(giorno);
    expect(aggiornata!.righe.single.fatto, isFalse);
    expect(aggiornata.todoFatti, 0);
  });

  test('un\'occorrenza ricorrente si segna e **non** si toglie', () async {
    scriviTodo('r1', ricorrenza: 'FREQ=WEEKLY;BYDAY=TH');
    ponte.preparaGiorno(pubblicato(righe: [riga('r1')]));

    await spuntaDalWidget(db: db, bridge: ponte, id: 'r1', giorno: giorno);
    expect(db.occurrences.isDone('r1', giorno), isTrue,
        reason: 'un ricorrente segna **solo** quel giorno');
    expect(db.getTodos().single['completed'], 0,
        reason: 'la serie resta intatta');

    // Toccare di nuovo non toglie: è il limite dell'app, replicato identico.
    await spuntaDalWidget(db: db, bridge: ponte, id: 'r1', giorno: giorno);
    expect(db.occurrences.isDone('r1', giorno), isTrue);
  });

  test('un id che non esiste non scrive niente', () async {
    ponte.preparaGiorno(pubblicato(righe: [riga('t1')]));

    final esito = await spuntaDalWidget(
      db: db,
      bridge: ponte,
      id: 'boh',
      giorno: giorno,
    );

    expect(esito, isFalse);
    expect(db.outbox.pending(), isEmpty);
    expect(ponte.aggiornamenti, 0);
  });

  test('senza pacchetto pubblicato la spunta si scrive lo stesso', () async {
    scriviTodo('t1');

    final esito = await spuntaDalWidget(
      db: db,
      bridge: ponte,
      id: 't1',
      giorno: giorno,
    );

    expect(esito, isTrue);
    expect(db.getTodos().single['completed'], 1);
    expect(ponte.aggiornamenti, 0,
        reason: 'non c\'è niente da ridisegnare: il widget non ha il pacchetto');
  });

  test('gli eventi non hanno nessuna azione: solo i todo si spuntano', () {
    final conEvento = pubblicato(
      righe: [
        const WidgetRow(
          id: 'e1',
          tipo: tipoEvento,
          titolo: 'Dentista',
          ora: '15:00',
          colore: '#111111',
          coloreScuro: '#111112',
        ),
      ],
      todo: 0,
    );

    final giornoDopo = conLaSpunta(conEvento, id: 'e1', fatto: true);

    expect(giornoDopo.righe.single.fatto, isFalse,
        reason: 'la spunta su una riga di evento non esiste: gli eventi non si '
            'spuntano né nell\'app né qui');
    expect(giornoDopo.todoFatti, 0);
  });
}
