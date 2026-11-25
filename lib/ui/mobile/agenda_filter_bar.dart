import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/filters/filtro_condiviso.dart';
import '../../features/filters/filtro_condiviso_controller.dart';
import '../../theme/design_tokens.dart';
import '../shared/filter_pill.dart';
import 'agenda_filter_sheets.dart';

/// La barra dei filtri dell'agenda: **cosa mostrare**, **fin dove** e **quali
/// categorie**.
///
/// Gli stessi tre comandi valgono per il calendario (è il *filtro condiviso*):
/// una lente sola per due schermate che mostrano gli stessi dati, non due filtri
/// che si allontanano.
///
/// I filtri vanno a capo con il testo ingrandito e restano tutti raggiungibili.
class AgendaFilterBar extends StatelessWidget {
  const AgendaFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FiltroCondivisoController>();
    final filtro = controller.filtro;
    final scelte = filtro.categorieScelte.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Wrap(
        spacing: AppSpacing.s,
        runSpacing: AppSpacing.xs,
        children: [
          FilterPill(
            key: const ValueKey('filtro-cosa'),
            testo: cosaMostrareLabels[filtro.cosa]!,
            icona: _iconaCosa(filtro.cosa),
            attiva: filtro.cosa != CosaMostrare.entrambi,
            onTap: () => showSceltaSheet<CosaMostrare>(
              context,
              titolo: 'Cosa mostrare',
              // L'ordine di lettura: tutto quello che c'è, e poi le due metà.
              opzioni: const [
                CosaMostrare.entrambi,
                CosaMostrare.eventi,
                CosaMostrare.todo,
              ],
              attuale: filtro.cosa,
              etichetta: (valore) => cosaMostrareLabels[valore]!,
              icona: _iconaCosa,
              onScelto: controller.setCosa,
            ),
          ),
          FilterPill(
            key: const ValueKey('filtro-orizzonte'),
            testo: orizzonteLabels[filtro.orizzonte]!,
            icona: Icons.date_range,
            // L'orizzonte ha sempre un valore (30 giorni è quello di partenza):
            // colorarlo come «filtro attivo» lo farebbe sembrare un vincolo.
            attiva: false,
            onTap: () => showSceltaSheet<Orizzonte>(
              context,
              titolo: 'Fin dove guardare',
              opzioni: Orizzonte.values,
              attuale: filtro.orizzonte,
              etichetta: (valore) => orizzonteLabels[valore]!,
              onScelto: controller.setOrizzonte,
            ),
          ),
          FilterPill(
            key: const ValueKey('filtro-categorie'),
            testo: scelte == 0 ? 'Categorie' : 'Categorie · $scelte',
            icona: Icons.label_outline,
            attiva: scelte > 0,
            onTap: () => showCategorieSheet(context),
          ),
        ],
      ),
    );
  }

  static IconData _iconaCosa(CosaMostrare cosa) => switch (cosa) {
        CosaMostrare.eventi => Icons.event_outlined,
        CosaMostrare.todo => Icons.checklist_outlined,
        // Non `view_agenda_*`: è l'icona della sezione, e sull'agenda vuota
        // comparirebbe due volte nella stessa schermata (l'ha visto il test
        // della centratura, che ne pretende una sola).
        CosaMostrare.entrambi => Icons.list_alt_outlined,
      };
}
