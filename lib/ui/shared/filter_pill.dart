import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Una **pastiglia di filtro**: icona, parola, e il chevron che dice che si apre.
///
/// Dice una cosa sola, e la dice in un modo: quando la scelta e' **fatta** cambia
/// fondo e colore ([attiva]), cosi' si vede che c'e' un filtro senza aprirlo (e
/// senza di lui ci si dimentica di averlo messo).
///
/// Sta in `shared/` perche' la usano l'agenda (la barra dei filtri condivisi) e la
/// scheda Todo: due schermate, **la stessa forma** — ed e' la forma che rende
/// riconoscibile un filtro.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.testo,
    required this.icona,
    this.attiva = false,
    this.onTap,
  });

  final String testo;
  final IconData icona;

  /// Vero quando questa e' una scelta **fatta**: cambia i colori.
  final bool attiva;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colore = attiva ? scheme.onSecondaryContainer : scheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: attiva ? scheme.secondaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icona,
              size: AppSpacing.iconSmall,
              color: attiva ? colore : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.s),
            Text(
              testo,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colore,
                  ),
            ),
            Icon(
              Icons.expand_more,
              size: AppSpacing.iconSmall,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
