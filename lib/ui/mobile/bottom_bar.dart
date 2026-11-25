import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

part 'bottom_bar_items.dart';

/// La barra di navigazione in basso: **Note, Todo, Calendario, Agenda,
/// Impostazioni** — con il Calendario **in mezzo e rialzato**.
///
/// Perché il Calendario al centro e con la pastiglia: è la schermata che si guarda
/// di più, e la pastiglia rialzata la indica senza rubare una voce alle altre
/// quattro. Il cerchio è **del colore della barra**, quindi si fonde con essa
/// (una collina, non un pulsante appoggiato sopra); quello che dice «sei qui» è
/// l'icona, che cambia colore e si accende di un anello.
///
/// È un widget nostro e non un `NavigationBar` di Material perché la collina esce
/// dal bordo superiore della barra: con il widget di sistema quel disegno si
/// ottiene solo forzandone le parti interne, e si rompe al primo aggiornamento.
/// Quello che si tiene di Material è quello che conta: aree toccabili da 48,
/// etichette sotto le icone, e la semantica di «pulsante, selezionato» per chi usa
/// un lettore di schermo.
class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.index,
    required this.onSelected,
  });

  /// La scheda che si sta guardando.
  final int index;

  final ValueChanged<int> onSelected;

  /// Le cinque schede, nell'ordine della barra. Il **Calendario** è la terza: sta
  /// in mezzo, ed è quella che porta la pastiglia.
  static const List<({IconData icona, IconData iconaPiena, String etichetta})>
      voci = [
    (
      icona: Icons.note_alt_outlined,
      iconaPiena: Icons.note_alt,
      etichetta: 'Note',
    ),
    (
      icona: Icons.checklist_outlined,
      iconaPiena: Icons.checklist,
      etichetta: 'To do',
    ),
    (
      icona: Icons.calendar_today_outlined,
      iconaPiena: Icons.calendar_today,
      etichetta: 'Calendario',
    ),
    (
      icona: Icons.view_agenda_outlined,
      iconaPiena: Icons.view_agenda,
      etichetta: 'Agenda',
    ),
    (
      icona: Icons.settings_outlined,
      iconaPiena: Icons.settings,
      etichetta: 'Impostazioni',
    ),
  ];

  /// La scheda con la pastiglia: il Calendario, in mezzo alle cinque.
  static const int centrale = 2;

  /// Quanto è alta la superficie della barra (sotto la collina). 66 e non 60:
  /// sotto la pastiglia l'etichetta ci deve stare, e col testo ingrandito di
  /// sistema (che sul telefono è a ~1,3) serve qualche pixel in più.
  static const double altezzaBarra = 66;

  /// Quanto la pastiglia esce sopra il bordo della barra.
  static const double rigonfiamento = 28;

  static const double diametroPastiglia = 56;

  /// L'altezza del testo delle etichette, alla scala corrente.
  static double _labelHeight(BuildContext context) {
    final stile = Theme.of(context).textTheme.labelSmall!;
    return MediaQuery.textScalerOf(context).scale(stile.fontSize ?? 11) *
        (stile.height ?? 1.2);
  }

  /// La barra cresce col testo: la pastiglia e la sua etichetta devono starci
  /// dentro senza rimpicciolire il nome.
  static double altezzaBarraDi(BuildContext context) => math.max(
        altezzaBarra,
        diametroPastiglia -
            rigonfiamento +
            2 * _labelHeight(context) +
            AppSpacing.s,
      );

  /// L'altezza totale della barra, pastiglia compresa: è quella che il guscio
  /// riserva in fondo allo schermo.
  static double altezza(BuildContext context) =>
      rigonfiamento +
      altezzaBarraDi(context) +
      MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: altezza(context),
      child: Stack(
        children: [
          // La superficie: parte **sotto** la collina, così la pastiglia può
          // uscire dal bordo senza che niente venga tagliato.
          Positioned(
            left: 0,
            right: 0,
            top: rigonfiamento,
            bottom: 0,
            child: ColoredBox(color: scheme.surfaceContainerLow),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: rigonfiamento,
            bottom: 0,
            child: Row(
              children: [
                for (var indice = 0; indice < voci.length; indice++)
                  Expanded(
                    child: indice == centrale
                        // Al centro il tocco è della pastiglia (che sta sopra):
                        // qui resta solo l'etichetta, e la semantica la porta lei.
                        ? _EtichettaCentrale(
                            testo: voci[indice].etichetta,
                            selezionata: indice == index,
                            onTap: () => onSelected(indice),
                          )
                        : _Voce(
                            voce: voci[indice],
                            selezionata: indice == index,
                            onTap: () => onSelected(indice),
                          ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _Pastiglia(
                voce: voci[centrale],
                selezionata: index == centrale,
                onTap: () => onSelected(centrale),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
