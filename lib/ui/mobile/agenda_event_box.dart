import 'package:flutter/material.dart';

import '../../features/events/domain/event_occurrence.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import '../shared/event_colors.dart';
import '../shared/formatters.dart';

/// Il box di un evento in agenda: **pieno col colore dell'evento**, titolo a
/// sinistra e orario a destra.
///
/// È il contrario del box del calendario (tinta tenue, barra colorata): qui
/// l'elenco è il protagonista della schermata, ed è il colore a dire a colpo
/// d'occhio a che cosa appartiene la riga. Il testo è **uno solo per tema**
/// (nero nel chiaro, bianco nel scuro): l'alternanza per box fra scritte bianche
/// e nere fila dopo fila era la segnalazione. Il fondo resta la tinta
/// dell'evento e si muove solo la luminosità quando serve a farlo leggere
/// ([ColorResolver.agendaFondo]); le to-do qui non cambiano: la regola vale
/// per gli eventi.
///
/// L'orario non c'è per gli eventi di **giornata intera**: hanno le 00:00 e le
/// 23:59 come orari veri, e scriverli sarebbe rumore.
class AgendaEventBox extends StatelessWidget {
  const AgendaEventBox({
    super.key,
    required this.occurrence,
    this.onTap,
    this.onLongPress,
  });

  final EventOccurrence occurrence;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colore = ColorResolver.agendaFondo(
      occurrenceColor(context, occurrence),
      theme.brightness,
    );
    final testo = ColorResolver.agendaTesto(theme.brightness);
    final raggio = BorderRadius.circular(AppRadius.chip);

    return Material(
      color: colore,
      borderRadius: raggio,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: raggio,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          child: Row(
            children: [
              // Il titolo prende quello che avanza e **cede** per primo: con il
              // testo ingrandito (sul telefono è a ~1,3) è quello che si può
              // tagliare, l'orario no.
              Expanded(
                child: Text(
                  occurrence.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: testo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!occurrence.event.allDay) ...[
                const SizedBox(width: AppSpacing.s),
                Text(
                  formatTimeRange(occurrence.start, occurrence.end),
                  maxLines: 1,
                  style: theme.textTheme.labelMedium?.copyWith(color: testo),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
