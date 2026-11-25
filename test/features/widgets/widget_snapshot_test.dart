import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/domain/event_occurrence.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/features/widgets/domain/widget_payload.dart';
import 'package:planner/features/widgets/widget_contract.dart';
import 'package:planner/features/widgets/widget_snapshot.dart';

/// Il **pacchetto** dei widget: cosa finisce dentro, in che ordine, con che
/// stato.
///
/// Perché conta: la logica che il widget mostra sta tutta qui — il Kotlin disegna
/// e basta. Le tre cose che si vedono a occhio e che qui si pretendono: l'ordine
/// (chi ha un'ora prima, e in ordine di ora), le due frasi degli stati vuoti
/// (giornata vuota ≠ tutto fatto), e i **conteggi veri** dietro il taglio delle
/// righe, senza i quali «+N altri» mentirebbe.
void main() {
  final oggi = DateTime(2026, 9, 24, 10, 0);

  EventOccurrence evento(
    String id,
    String titolo, {
    int ora = 14,
    int durata = 60,
    bool tuttoIlGiorno = false,
    List<String> categoria = const [],
  }) {
    final inizio = DateTime(2026, 9, 24, ora, 0);
    return EventOccurrence(
      event: Event(
        id: id,
        title: titolo,
        start: inizio,
        end: inizio.add(Duration(minutes: durata)),
        allDay: tuttoIlGiorno,
        categoryIds: categoria,
      ),
      date: DateTime(2026, 9, 24),
      start: inizio,
      end: inizio.add(Duration(minutes: durata)),
    );
  }

  Todo todo(
    String id,
    String titolo, {
    int? inizio,
    int? fine,
    int priorita = 0,
    bool fatto = false,
    List<String> categoria = const [],
  }) =>
      Todo(
        id: id,
        title: titolo,
        startMinutes: inizio,
        endMinutes: fine,
        priority: priorita,
        dueDate: DateTime(2026, 9, 24),
        completed: fatto,
        categoryIds: categoria,
      );

  /// Il materiale con dentro quello che serve al test: gli altri giorni sono
  /// vuoti.
  MaterialeDelWidget materiale(
    List<EventOccurrence> eventi,
    List<Todo> todos, {
    required bool Function(Todo) fatto,
    DateTime? adesso,
  }) =>
      MaterialeDelWidget(
        adesso: adesso ?? oggi,
        eventiDelGiorno: (giorno) => giorno.day == 24 ? eventi : const [],
        todoDelGiorno: (giorno) => giorno.day == 24 ? todos : const [],
        todoFatto: (elemento, _) => fatto(elemento),
        coloreEvento: (evento, brightness) =>
            brightness == Brightness.light ? '#111111' : '#111112',
        coloreTodo: (elemento, brightness) =>
            brightness == Brightness.light ? '#222222' : '#222223',
        emoji: (categorie) => categorie.isEmpty ? '' : '🏠',
        etichettaDelGiorno: (giorno) =>
            giorno.day == 24 ? 'Oggi · gio 24 set' : 'ven 25 set',
      );

  test('la giornata vuota dice «Niente in programma per oggi»', () {
    final giorno = giornoDelWidget(
      DateTime(2026, 9, 24),
      materiale(const [], const [], fatto: (_) => false),
    );

    expect(giorno.stato, StatoDelGiorno.vuoto);
    expect(giorno.righe, isEmpty);
    expect(giorno.eventi, 0);
    expect(giorno.todo, 0);
    expect(giorno.etichetta, 'Oggi · gio 24 set');
  });

  test('tutti i todo fatti e nessun evento aperto: «Nient\'altro»', () {
    final giorno = giornoDelWidget(
      DateTime(2026, 9, 24),
      materiale(
        const [],
        [todo('t1', 'Spesa', fatto: true), todo('t2', 'Palestra', fatto: true)],
        fatto: (elemento) => elemento.completed,
      ),
    );

    expect(giorno.stato, StatoDelGiorno.tuttoFatto);
    expect(giorno.todoFatti, 2);
    expect(giorno.todoDaFare, 0);
    expect(giorno.righe, hasLength(2),
        reason: 'le righe restano: una spunta sbagliata si toglie dal widget');
  });

  test('un evento futuro lascia la giornata aperta', () {
    final giorno = giornoDelWidget(
      DateTime(2026, 9, 24),
      materiale(
        [evento('e1', 'Dentista', ora: 15)],
        [todo('t1', 'Spesa', fatto: true)],
        fatto: (elemento) => elemento.completed,
      ),
    );

    expect(giorno.stato, StatoDelGiorno.ok);
    expect(giorno.eventi, 1);
  });

  test('un giorno con eventi non è mai «tutto fatto», anche coi todo finiti',
      () {
    final giorno = giornoDelWidget(
      DateTime(2026, 9, 24),
      materiale(
        [evento('e1', 'Riunione', ora: 8, durata: 60)],
        [todo('t1', 'Spesa', fatto: true)],
        fatto: (elemento) => elemento.completed,
      ),
    );

    expect(giorno.stato, StatoDelGiorno.ok,
        reason: 'i todo sono fatti ma l\'evento era **in programma**: dire '
            '«nient\'altro» sarebbe falso, e la regola non guarda l\'ora (un '
            'widget che si contraddice da solo è peggio di uno severo)');
    expect(giorno.todoDaFare, 0);
  });

  test(
      'l\'ordine: prima chi ha un\'ora, poi gli eventi senza orario, poi i todo',
      () {
    final giorno = giornoDelWidget(
      DateTime(2026, 9, 24),
      materiale(
        [
          evento('e1', 'Dentista', ora: 16),
          evento('e2', 'Compleanno', tuttoIlGiorno: true),
          evento('e3', 'Lezione', ora: 9),
        ],
        [
          todo('t1', 'Spesa', inizio: 11 * 60),
          todo('t2', 'Chiamare il commercialista', priorita: 3),
          todo('t3', 'Leggere', priorita: 1),
        ],
        fatto: (_) => false,
      ),
    );

    expect(
      [for (final riga in giorno.righe) riga.titolo],
      [
        'Lezione', // 09:00
        'Spesa', // 11:00
        'Dentista', // 16:00
        'Compleanno', // tutto il giorno (senza orario)
        'Chiamare il commercialista', // priorità 3 (urgente)
        'Leggere', // priorità 1
      ],
    );
    expect(giorno.righe.first.ora, '09:00');
    expect(giorno.righe[3].tuttoIlGiorno, isTrue);
    expect(giorno.righe[3].ora, '');
  });

  test('l\'evento in corso adesso è segnato, gli altri no', () {
    final giorno = giornoDelWidget(
      DateTime(2026, 9, 24),
      materiale(
        [
          evento('e1', 'Adesso', ora: 9, durata: 120),
          evento('e2', 'Dopo', ora: 15),
          evento('e3', 'Prima', ora: 7, durata: 60),
        ],
        const [],
        fatto: (_) => false,
        adesso: DateTime(2026, 9, 24, 10, 0),
      ),
    );

    final inCorso = [
      for (final riga in giorno.righe)
        if (riga.inCorso) riga.titolo,
    ];
    expect(inCorso, ['Adesso']);
  });

  test('gli eventi non si spuntano mai: `fatto` è falso anche se confermati',
      () {
    final giorno = giornoDelWidget(
      DateTime(2026, 9, 24),
      materiale(
        [evento('e1', 'Confermato')],
        const [],
        fatto: (_) => true, // come se l'occorrenza fosse confermata
      ),
    );

    expect(giorno.righe.single.fatto, isFalse,
        reason: 'gli eventi non sono spuntabili nell\'app, quindi non lo sono '
            'nemmeno nel widget');
  });

  test('i todo portano colore ed emoji della categoria', () {
    final giorno = giornoDelWidget(
      DateTime(2026, 9, 24),
      materiale(
        [
          evento('e1', 'Cena', categoria: const ['cat-1'])
        ],
        [
          todo('t1', 'Spesa', categoria: const ['cat-1'])
        ],
        fatto: (_) => false,
      ),
    );

    expect(giorno.righe[0].colore, '#111111');
    expect(giorno.righe[1].colore, '#222222');
    expect(giorno.righe[0].coloreScuro, '#111112',
        reason: 'i due temi hanno due tinte: una tinta piena su fondo nero '
            'sparisce');
    expect(giorno.righe[1].coloreScuro, '#222223');
    expect(giorno.righe[0].emoji, '🏠');
    expect(giorno.righe[1].emoji, '🏠');
  });

  test('oltre le righe del pacchetto i conteggi restano quelli veri', () {
    final eventi = [
      for (var i = 0; i < righeNelPacchetto + 5; i++)
        evento('e$i', 'Evento $i', ora: 8 + i),
    ];
    final giorno = giornoDelWidget(
      DateTime(2026, 9, 24),
      materiale(eventi, const [], fatto: (_) => false),
    );

    expect(giorno.righe, hasLength(righeNelPacchetto));
    expect(giorno.eventi, righeNelPacchetto + 5,
        reason: '«+N altri» conta dal conteggio vero, non da quello che è '
            'arrivato');
  });

  test('il pacchetto copre otto giorni con le chiavi giuste', () {
    final pacchetto = pacchettoDelWidget(
      oggi: oggi,
      materiale: materiale(const [], const [], fatto: (_) => false),
    );

    expect(pacchetto, hasLength(giorniNelPacchetto));
    // La chiave si riempie con lo zero **e** porta la data vera: il pacchetto
    // scavalca il mese, quindi l'ottavo giorno è il 1° ottobre e non un
    // «31 settembre» normalizzato dal costruttore di `DateTime`.
    expect(chiaveGiorno(DateTime(2026, 9, 5)), 'widget_giorno_2026-09-05');
    expect(chiaveGiorno(DateTime(2026, 10, 1)), 'widget_giorno_2026-10-01',
        reason: 'il pacchetto di otto giorni scavalca il mese');
    for (var scarto = 0; scarto < giorniNelPacchetto; scarto++) {
      final giorno = DateTime(2026, 9, 24 + scarto);
      expect(pacchetto[giorno], isNotNull,
          reason: 'manca il giorno $giorno nel pacchetto');
      expect(pacchetto[giorno]!.data, giorno);
    }
  });

  test('i nomi dei provider sono qualificati, e il nome semplice resta dentro',
      () {
    // Il difetto trovato sul telefono il 24/09: il plugin risolve `name` **contro
    // l'app id** ("${packageName}.${className}"), quindi passargli il nome già
    // qualificato lo raddoppia e l'aggiornamento fallisce in
    // `PlatformException(-3)` — con il widget che resta fermo a quello che ha.
    for (final provider in providerDeiWidget) {
      expect(provider.qualificato, startsWith('com.callmeste.planner.'));
      expect(provider.qualificato, endsWith('.${provider.nome}'),
          reason: 'il nome semplice e quello qualificato devono essere lo '
              'stesso provider');
    }
  });

  test('l\'URI della spunta torna indietro come l\'ha scritto il widget', () {
    final uri = uriSpunta(id: 't1', giorno: DateTime(2026, 9, 24));
    final tocca = leggiToccaDelWidget(uri);

    expect(tocca, isNotNull);
    expect(tocca!.azione, 'spunta');
    expect(tocca.tipo, 'todo');
    expect(tocca.id, 't1');
    expect(tocca.giorno, DateTime(2026, 9, 24));

    // Un URI che non è nostro (o scritto male) non deve far saltare niente: il
    // callback di sfondo gira senza nessuno che guardi.
    expect(leggiToccaDelWidget(null), isNull);
    expect(leggiToccaDelWidget(Uri.parse('https://example.com')), isNull);
    expect(leggiToccaDelWidget(Uri.parse('planner://boh?id=1')), isNull);
    final senzaGiorno =
        leggiToccaDelWidget(Uri.parse('planner://apri?tipo=todo'));
    expect(senzaGiorno, isNotNull);
    expect(senzaGiorno!.giorno, isNull);
  });
}
