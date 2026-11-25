/// La **memoria delle celle** di un mese: la firma con cui si riconoscono, la
/// preparazione di tutte insieme, e la cache per mese.
///
/// Perché un file suo: `month_grid_cells.dart` ha il tetto delle righe, e queste
/// sono una cosa sola — "cosa rende valide le celle di un mese, e come si
/// preparano tutte". **Dove** si tengono lo dice `CachePerMese` (`month_cache.dart`),
/// e il *come* si prepara una cella sta nell'altro file.
library;

import 'package:flutter/material.dart';

import '../../features/calendar/month_grid_geometry.dart';
import '../../features/events/domain/event_occurrence.dart';
import 'month_cache.dart';
import 'month_grid_cells.dart';
import 'month_grid_painter.dart';

Object firmaDelleCelle({
  required DateTime mese,
  required (int, int) generazione,
  required DateTime selezione,
  required DateTime oggi,
  required StiliDelMese stili,
  required bool conTodo,
  required String filtro,
  required double larghezzaNumero,
}) =>
    (
      mese.year,
      mese.month,
      generazione,
      // Il **giorno** della selezione, non solo «la selezione e' in questo mese»:
      // il cerchio del giorno scelto e' **cotto dentro** le celle (evidenza e
      // colore del numero), quindi con un si'/no la memoria di quel mese restava
      // quella di prima e il cerchio tornava sul giorno di partenza appena
      // finiva l'animazione (segnalato sul telefono il 24/09). Il numero del
      // giorno entra nella firma **solo** per il mese che lo contiene: i mesi
      // vicini, che il precaricamento scalda, restano validi.
      selezione.year == mese.year && selezione.month == mese.month
          ? selezione.day
          : null,
      // Stessa regola per **oggi**, che e' colorato e in grassetto: a mezzanotte
      // quel giorno cambia dentro lo stesso mese.
      oggi.year == mese.year && oggi.month == mese.month ? oggi.day : null,
      // I **todo nel calendario**: con la modalita' «nascosta» i pallini non si
      // disegnano, e senza questo campo le celle gia' in memoria continuerebbero
      // a mostrarli (la firma e' l'unica cosa che le invalida).
      conTodo,
      // Il **filtro** condiviso: barre e pallini delle celle sono preparati dai
      // dati filtrati, quindi una cella preparata prima del filtro resta quella
      // di prima finche' la firma non cambia. Stessa trappola della modalita'
      // «nascosta», stesso rimedio: il filtro entra nella firma.
      filtro,
      // Gli **stili**, non le misure della riga: un paragrafo misurato non
      // dipende da quanto è alta una riga (il testo è lo stesso, cambia solo dove
      // finisce la cella — e quello lo sa il painter).
      stili.numero,
      stili.oltre,
      stili.badge,
      larghezzaNumero,
    );

/// Le celle di un mese, tutte: i 35 o 42 giorni che la griglia disegna.
///
/// La stessa strada che prende la griglia quando si disegna, e la prende **anche
/// il precaricamento**: scaldare una cache che nessuno legge non servirebbe a
/// niente. Delle misure della geometria qui non serve nessuna (i paragrafi non
/// dipendono dall'altezza delle righe): restano a zero.
List<GiornoPronto> preparaLeCelle({
  required DateTime mese,
  required DateTime selezione,
  required DateTime oggi,
  required Map<DateTime, List<EventOccurrence>> eventsByDay,
  required Map<DateTime, int> todoCounts,
  required StiliDelMese stili,
  required ColorScheme scheme,
  required Color Function(EventOccurrence evento) coloreEvento,
  required double larghezzaNumero,
}) {
  final geometria = MonthGridGeometry(month: mese);
  return [
    for (var indice = 0; indice < geometria.giorni; indice++)
      preparaGiorno(
        indice: indice,
        giorno: geometria.giornoA(indice),
        mese: mese,
        selezione: selezione,
        oggi: oggi,
        stili: stili,
        scheme: scheme,
        eventsByDay: eventsByDay,
        todoCounts: todoCounts,
        coloreEvento: coloreEvento,
        larghezzaNumero: larghezzaNumero,
      ),
  ];
}

/// Prepara le celle di [mese] **e le mette in memoria**: è la strada che prende
/// il precaricamento per scaldare i mesi vicini in un fotogramma inattivo.
///
/// La firma la calcola [firmaDelleCelle]: la stessa che calcola la griglia quando
/// disegna, altrimenti le celle preparate qui sarebbero "diverse" da quelle che
/// servono.
List<GiornoPronto> scaldaLeCelle({
  required CachePerMese<List<GiornoPronto>> celle,
  required DateTime mese,
  required DateTime selezione,
  required DateTime oggi,
  required (int, int) generazione,
  required bool conTodo,
  required String filtro,
  required Map<DateTime, List<EventOccurrence>> eventsByDay,
  required Map<DateTime, int> todoCounts,
  required StiliDelMese stili,
  required ColorScheme scheme,
  required Color Function(EventOccurrence evento) coloreEvento,
  required double larghezzaNumero,
}) =>
    celle.di(
      mese: mese,
      firma: firmaDelleCelle(
        mese: mese,
        generazione: generazione,
        selezione: selezione,
        oggi: oggi,
        stili: stili,
        conTodo: conTodo,
        filtro: filtro,
        larghezzaNumero: larghezzaNumero,
      ),
      prepara: () => preparaLeCelle(
        mese: mese,
        selezione: selezione,
        oggi: oggi,
        eventsByDay: eventsByDay,
        todoCounts: todoCounts,
        stili: stili,
        scheme: scheme,
        coloreEvento: coloreEvento,
        larghezzaNumero: larghezzaNumero,
      ),
    );
