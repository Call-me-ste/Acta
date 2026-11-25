import 'dart:convert';
import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/domain/event_occurrence.dart';
import 'package:planner/features/widgets/domain/widget_mese.dart';
import 'package:planner/features/widgets/widget_contract.dart';
import 'package:planner/features/widgets/widget_mese_snapshot.dart';
import 'package:planner/features/widgets/widget_snapshot.dart';

/// Il **pacchetto del mese**: la griglia, i conteggi veri e i confini della
/// finestra.
///
/// Perché conta: il widget mensile non ha una logica sua in Kotlin — disegna
/// quello che questo file gli consegna. Le cose che si vedono a occhio e che qui
/// si pretendono: ogni settimana comincia di lunedì, il numero di righe è quello
/// del mese (4, 5 o 6), i giorni dei mesi adiacenti ci sono e sono segnati, i
/// conteggi non mentono dietro le due anteprime, e fuori dalla finestra non si
/// mostrano giorni vecchi.
void main() {
  /// Le finestre chieste al provider: serve a pretendere **una** passata.
  late List<(DateTime, DateTime)> ultimeChiamate;

  EventOccurrence occorrenza(
    String id,
    DateTime giorno, {
    String titolo = 'Evento',
    int ora = 9,
    bool tuttoIlGiorno = false,
  }) {
    final inizio = tuttoIlGiorno
        ? DateTime(giorno.year, giorno.month, giorno.day)
        : DateTime(giorno.year, giorno.month, giorno.day, ora);
    return EventOccurrence(
      event: Event(
        id: id,
        title: titolo,
        start: inizio,
        end: inizio.add(const Duration(hours: 1)),
        allDay: tuttoIlGiorno,
      ),
      date: DateTime(giorno.year, giorno.month, giorno.day),
      start: inizio,
      end: inizio.add(const Duration(hours: 1)),
    );
  }

  /// Il materiale del mese: gli eventi si passano **tutti insieme**, come fa
  /// `EventProvider.occurrencesBetween` — una passata sola per finestra.
  MaterialeDelMese materiale(List<EventOccurrence> eventi, {DateTime? adesso}) {
    final chiamate = <(DateTime, DateTime)>[];
    final risultato = MaterialeDelMese(
      adesso: adesso ?? DateTime(2026, 9, 24, 10),
      eventiIntervallo: (da, il) {
        chiamate.add((da, il));
        return [
          for (final evento in eventi)
            if (!evento.date.isBefore(da) && evento.date.isBefore(il)) evento,
        ];
      },
      coloreEvento: (evento, luminosita) =>
          luminosita == Brightness.dark ? '#111111' : '#eeeeee',
      etichettaDelMese: (mese) => 'mese ${mese.month}/${mese.year}',
    );
    // Il test delle chiamate: la griglia non deve fare 42 domande.
    ultimeChiamate = chiamate;
    return risultato;
  }

  test('febbraio bisestile: 29 giorni e cinque settimane', () {
    final mese = meseDelWidget(DateTime(2028, 2), materiale(const []));

    expect(mese.settimane, 5);
    expect(mese.giorni.length, 35);
    expect(
      [
        for (final giorno in mese.giorni)
          if (!giorno.fuoriMese) giorno.giorno
      ],
      List.generate(29, (indice) => indice + 1),
    );
  });

  test(
      'febbraio che comincia di lunedì: quattro settimane, nessun giorno '
      'in più', () {
    // 1 febbraio 2027 è un lunedì.
    final mese = meseDelWidget(DateTime(2027, 2), materiale(const []));

    expect(mese.settimane, 4);
    expect(mese.giorni.length, 28);
    expect(mese.giorni.where((giorno) => giorno.fuoriMese), isEmpty);
  });

  test('un mese che comincia di sabato: sei settimane', () {
    // 1 agosto 2026 è un sabato.
    final mese = meseDelWidget(DateTime(2026, 8), materiale(const []));

    expect(mese.settimane, 6);
    expect(mese.giorni.length, 42);
    expect(mese.giorni.first.data, '2026-07-27',
        reason: 'la prima riga comincia dal lunedì della settimana del primo');
    expect(mese.giorni.first.fuoriMese, isTrue);
    expect(mese.giorni.last.data, '2026-09-06');
    expect(mese.giorni.last.fuoriMese, isTrue);
  });

  test('la griglia comincia sempre di lunedì e finisce sempre di domenica', () {
    for (var mese = 1; mese <= 12; mese++) {
      final pronto = meseDelWidget(
        DateTime(2026, mese),
        materiale(const []),
      );
      expect(
        DateTime.parse(pronto.giorni.first.data).weekday,
        DateTime.monday,
        reason: 'mese $mese: la prima cella deve essere un lunedì',
      );
      expect(
        DateTime.parse(pronto.giorni.last.data).weekday,
        DateTime.sunday,
        reason: 'mese $mese: l\'ultima cella deve essere una domenica',
      );
      expect(pronto.giorni.length, pronto.settimane * 7);
    }
  });

  test('le ricorrenze sono già occorrenze: ogni giorno conta la sua', () {
    // Lo stesso evento ricorrente arriva come due occorrenze in due giorni.
    final eventi = [
      occorrenza('ripeti', DateTime(2026, 9, 7), titolo: 'Palestra'),
      occorrenza('ripeti', DateTime(2026, 9, 14), titolo: 'Palestra'),
    ];
    final mese = meseDelWidget(DateTime(2026, 9), materiale(eventi));

    expect(mese.giorni.firstWhere((g) => g.data == '2026-09-07').eventi, 1);
    expect(mese.giorni.firstWhere((g) => g.data == '2026-09-14').eventi, 1);
    expect(
      mese.giorni.firstWhere((g) => g.data == '2026-09-21').eventi,
      0,
      reason: 'una ricorrenza non si moltiplica nei giorni vicini',
    );
  });

  test('una passata sola per la griglia, non una per giorno', () {
    meseDelWidget(DateTime(2026, 9), materiale(const []));

    expect(ultimeChiamate, hasLength(1),
        reason: 'la griglia chiede **una** finestra, non 35 giorni');
    expect(ultimeChiamate.single.$1, DateTime(2026, 8, 31));
    expect(ultimeChiamate.single.$2, DateTime(2026, 10, 5));
  });

  test('due anteprime al massimo, il conteggio resta vero', () {
    final eventi = [
      for (var ora = 9; ora <= 12; ora++)
        occorrenza('e$ora', DateTime(2026, 9, 3), ora: ora, titolo: 'E$ora'),
    ];
    final mese = meseDelWidget(DateTime(2026, 9), materiale(eventi));
    final giorno = mese.giorni.firstWhere((g) => g.data == '2026-09-03');

    expect(giorno.eventi, 4);
    expect(giorno.anteprime, hasLength(2));
    // Le prime due della giornata, non le prime capitate.
    expect([for (final a in giorno.anteprime) a.titolo], ['E9', 'E10']);
    expect(giorno.altre, 2, reason: '«+2» è la differenza vera');
    expect(giorno.anteprime.first.colore, '#eeeeee');
    expect(giorno.anteprime.first.coloreScuro, '#111111');
  });

  test('giorno vuoto: nessun evento, nessuna anteprima, nessun +N', () {
    final mese = meseDelWidget(DateTime(2026, 9), materiale(const []));
    final giorno = mese.giorni.firstWhere((g) => g.data == '2026-09-24');

    expect(giorno.eventi, 0);
    expect(giorno.anteprime, isEmpty);
    expect(giorno.altre, 0);
  });

  test('oggi è segnato solo nel giorno giusto', () {
    final mese = meseDelWidget(
      DateTime(2026, 9),
      materiale(const [], adesso: DateTime(2026, 9, 24, 23, 59)),
    );

    expect(
      [
        for (final g in mese.giorni)
          if (g.oggi) g.data
      ],
      ['2026-09-24'],
    );
  });

  test('round-trip del JSON: il Kotlin legge gli stessi nomi', () {
    final eventi = [occorrenza('a', DateTime(2026, 9, 3), titolo: 'Dentista')];
    final mese = meseDelWidget(DateTime(2026, 9), materiale(eventi));

    final copia = WidgetMese.fromJson(
      (jsonDecode(jsonEncode(mese.toJson())) as Map).cast<String, Object?>(),
    );

    expect(copia.anno, 2026);
    expect(copia.mese, 9);
    expect(copia.settimane, mese.settimane);
    expect(copia.giorni.length, mese.giorni.length);
    expect(copia.giorni.first.data, mese.giorni.first.data);
    final giorno = copia.giorni.firstWhere((g) => g.data == '2026-09-03');
    expect(giorno.eventi, 1);
    expect(giorno.anteprime.single.titolo, 'Dentista');
    expect(giorno.anteprime.single.colore, '#eeeeee');
  });

  test('la finestra è il mese corrente e i due adiacenti', () {
    final mesi = pacchettoDeiMesi(
      oggi: DateTime(2026, 9, 24),
      materiale: materiale(const []),
    );

    expect(
      [for (final mese in mesi.keys) annoMeseIso(mese)],
      ['2026-08', '2026-09', '2026-10'],
    );
    expect(mesi[DateTime(2026, 9)]?.mese, 9);
  });

  test('la finestra attraversa l\'anno senza sbagliare mese', () {
    final mesi = pacchettoDeiMesi(
      oggi: DateTime(2026, 1, 3),
      materiale: materiale(const []),
    );

    expect(
      [for (final mese in mesi.keys) annoMeseIso(mese)],
      ['2025-12', '2026-01', '2026-02'],
    );
  });

  test('le chiavi del mese non toccano quelle degli otto giorni', () {
    final mese = DateTime(2026, 9);
    expect(chiaveMese(mese), 'widget_mese_2026-09');
    expect(annoMeseIso(mese), '2026-09');

    // Il pacchetto della giornata resta quello di prima: otto chiavi distinte.
    final giorni = pacchettoDelWidget(
      oggi: DateTime(2026, 9, 24),
      materiale: MaterialeDelWidget(
        adesso: DateTime(2026, 9, 24, 10),
        eventiDelGiorno: (_) => const [],
        todoDelGiorno: (_) => const [],
        todoFatto: (_, __) => false,
        coloreEvento: (_, __) => '#000000',
        coloreTodo: (_, __) => '#000000',
        emoji: (_) => '',
        etichettaDelGiorno: (giorno) => dataIso(giorno),
      ),
    );

    expect(giorni, hasLength(giorniNelPacchetto));
    expect(chiaveGiorno(DateTime(2026, 9, 24)), 'widget_giorno_2026-09-24');
    expect(
      {for (final giorno in giorni.keys) chiaveGiorno(giorno)},
      isNot(contains(chiaveMese(mese))),
    );
  });
}
