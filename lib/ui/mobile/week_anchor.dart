import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../shared/date_math.dart';
import 'calendar_jumps.dart';

/// Il riallineamento orizzontale della vista settimana.
///
/// La regola e' una sola: la colonna del **giorno scelto** va alla prima a
/// sinistra **quando c'è posto**; da giovedì in poi, con tre giorni e mezzo
/// visibili, lo spazio a destra finisce e la vista si ferma al fondo — il giorno
/// resta comunque visibile per intero.
///
/// E scorrere restando sullo stesso giorno non muove niente: chi scorre sta
/// leggendo, e riportarlo su sarebbe una prepotenza.
///
/// Il **lunedì** all'apertura di una settimana nuova non si ottiene da qui: lo
/// garantisce la selezione, che passando di settimana va sempre al lunedì (vedi
/// `calendar_page`). Così la regola resta una invece di due.
///
/// La **prima** volta il posizionamento salta invece di animare: all'apertura le
/// tre viste si costruiscono, e quella che non si vede sta fuori scena dove i
/// ticker sono fermi — un'animazione lì non arriverebbe mai. E un primo
/// posizionamento non è un movimento: non c'è niente da ammorbidire.
class WeekAnchor {
  DateTime? _giorno;

  /// Da chiamare nel `build` della vista, con i valori di adesso.
  ///
  /// Muove **tutti e tre** i pannelli allo stesso bersaglio, con la stessa durata e
  /// la stessa curva: il movimento è identico per costruzione. Era animato uno solo
  /// (la griglia) con gli altri appesi al suo scorrimento, e il risultato era che
  /// dopo un riallineamento le date restavano indietro di una colonna — trovato da
  /// una prova, non a occhio: la tinta del giorno a 40 px e la cella della sua data
  /// a -63.
  void allinea({
    required DateTime weekStart,
    required DateTime selectedDay,
    required double columnWidth,
    required List<ScrollController> pannelli,
    required bool animate,
  }) {
    final giorno = dateOnly(selectedDay);
    if (_giorno == giorno) return;

    // Prima volta: la vista si sta aprendo (o si sta costruendo fuori scena).
    final primaVolta = _giorno == null;

    // Fuori scena le misure non sono ancora quelle vere: la larghezza di colonna
    // esce a zero o sotto, e un allineamento calcolato su quella sarebbe un salto
    // a caso. Era proprio questo il difetto: la settimana si apriva sul lunedi'
    // invece che sul giorno scelto, perche' il primo giro (fuori scena) segnava
    // l'allineamento come fatto con un bersaglio sbagliato. Qui non si segna
    // niente: il `LayoutBuilder` ricostruisce quando arrivano misure vere, e
    // l'allineamento si fa allora.
    if (columnWidth <= 0) return;

    // La colonna del giorno scelto finisce a sinistra, **entro i limiti della
    // settimana**: da giovedi' in poi lo spazio a destra finisce e ci si ferma al
    // fondo, con il giorno comunque tutto dentro. Il lunedi' all'apertura di una
    // settimana nuova non si ottiene qui: lo garantisce la selezione, che va
    // sempre al lunedi' (vedi `calendar_page`).
    final bersaglio =
        CalendarJumps.distanzaInGiorni(weekStart, giorno) * columnWidth;

    // **Dopo il disegno**: la larghezza di colonna si conosce solo lì, e cambiando
    // settimana la pagina si deve prima disporre.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Non ancora disposta: non si segna niente e si riprova al giro dopo.
      final attivi = [
        for (final pannello in pannelli)
          if (pannello.hasClients) pannello,
      ];
      if (attivi.isEmpty) return;

      _giorno = giorno;

      final destinazione =
          bersaglio.clamp(0.0, attivi.first.position.maxScrollExtent);
      // Si muovono **tutti**, non solo quelli fuori posto: se uno è rimasto
      // indietro (o lo era già), questo lo rimette in riga invece di lasciarlo
      // storto per sempre.
      final tuttiAPosto =
          attivi.every((p) => (p.offset - destinazione).abs() < 0.5);
      if (tuttiAPosto) return;

      // La **prima** volta (e con le animazioni spente) si salta: all'apertura le
      // altre viste si costruiscono fuori scena, e fuori scena i ticker sono fermi
      // (`ViewPushSwitcher`) — un'animazione lì non arriverebbe mai, e la vista
      // resterebbe al lunedì invece che sul giorno scelto. E il primo
      // posizionamento non è un movimento: non c'è niente da ammorbidire.
      if (animate && !primaVolta) {
        // 360 ms e non 220: uno scorrimento di mezza schermata a 220 ms si legge
        // come uno scatto.
        for (final pannello in attivi) {
          pannello.animateTo(
            destinazione,
            duration: AppMotion.slow,
            curve: AppMotion.curve,
          );
        }
      } else {
        for (final pannello in attivi) {
          pannello.jumpTo(destinazione);
        }
      }
    });
  }
}
