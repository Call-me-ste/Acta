import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/settings/app_settings_controller.dart';
import '../../features/settings/priority_colors.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';

/// Come si dice e come si vede una **priorita'**: 0 Bassa, 1 Media, 2 Alta,
/// 3 Urgente.
///
/// Sta in un posto solo perche' la priorita' compare in quattro punti — scheda
/// del todo, striscia del giorno, celle del mese, filtri — e quattro copie di
/// "quale colore per quale livello" sono quattro occasioni di sbagliarlo.
const List<String> priorityLabels = ['Bassa', 'Media', 'Alta', 'Urgente'];

int clampPriority(int priority) => priority.clamp(0, priorityLabels.length - 1);

String priorityLabel(int priority) => priorityLabels[clampPriority(priority)];

/// I colori vengono da **Impostazioni > Organizzazione > Priorita'** (di base:
/// azzurro, giallo, arancione, rosso), non dal tema: il tema cambia con la
/// palette, mentre "urgente e' rosso" deve restare vero comunque.
Color priorityColor(BuildContext context, int priority) {
  final colors = context.watch<AppSettingsController>().priorityColors;
  return priorityColorFrom(colors, priority);
}

/// Il colore di un livello a partire da un elenco di hex: **funzione pura**,
/// cosi' la stessa regola vale per il widget e per le prove senza tirare in
/// mezzo il contesto.
Color priorityColorFrom(Iterable<String> colors, int priority) {
  final index = clampPriority(priority);
  final hex = colors.elementAtOrNull(index);
  return ColorResolver.hexToColor(hex) ??
      ColorResolver.hexToColor(defaultPriorityColors[index])!;
}

/// Il colore per **testo e icona**: su tema chiaro una tinta piena come il
/// giallo non si legge sul fondo della pastiglia, quindi si scurisce. La
/// barretta invece resta piena: e' una superficie, non una scritta.
Color priorityInk(BuildContext context, int priority) {
  final base = priorityColor(context, priority);
  return Theme.of(context).brightness == Brightness.dark
      ? base
      : ColorResolver.darkVariant(base);
}

/// L'icona che accompagna la parola: un segno in piu' oltre al colore, per chi i
/// colori non li distingue. La barra cresce col livello, e l'urgente e' un punto
/// esclamativo, che si legge a colpo d'occhio anche in piccolo.
IconData priorityIcon(int priority) => switch (clampPriority(priority)) {
      3 => Icons.priority_high,
      2 => Icons.signal_cellular_alt,
      1 => Icons.signal_cellular_alt_2_bar,
      _ => Icons.signal_cellular_alt_1_bar,
    };

/// La pastiglia della priorita': icona **e** parola, non solo il colore.
class PriorityChip extends StatelessWidget {
  const PriorityChip({super.key, required this.priority, this.compact = false});

  final int priority;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colore = priorityInk(context, priority);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.15),
        borderRadius: AppRadius.pillRadius(compact ? 20 : 24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(priorityIcon(priority), size: compact ? 13 : 15, color: colore),
          const SizedBox(width: AppSpacing.xs),
          Text(
            priorityLabel(priority),
            style: (compact
                    ? theme.textTheme.labelSmall
                    : theme.textTheme.labelMedium)
                ?.copyWith(color: colore),
          ),
        ],
      ),
    );
  }
}
