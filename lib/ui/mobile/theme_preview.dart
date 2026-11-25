import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// L'anteprima del tema: una giornata in miniatura — il fondo, una superficie con
/// un evento e un todo, il testo e l'accento.
///
/// Perché esiste: la recensione diceva che «non c'è modo di vedere **l'effetto** di
/// una scelta senza uscire e rientrare nelle schermate». Qui si vede mentre si
/// sceglie: è la prima cosa del foglio del colore, e lo schema che disegna arriva
/// dalla stessa strada dell'app (`AppTheme.schemeFor`), non da un'imitazione.
///
/// I pezzi colorati sono `ColoredBox` con una chiave: così una prova può **leggere**
/// il colore invece di guardarlo.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('anteprima-fondo'),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // La barra del titolo, con l'accento.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: ColoredBox(
                key: const ValueKey('anteprima-accento'),
                color: scheme.primary,
                child: const SizedBox(height: 8, width: 56),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              key: const ValueKey('anteprima-testo'),
              'Oggi',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            // Una superficie con dentro le due cose che l'app mostra davvero.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: ColoredBox(
                key: const ValueKey('anteprima-superfici'),
                color: scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Riga(
                        colore: scheme.primary,
                        onColore: scheme.onPrimary,
                        testo: 'Evento',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _Riga(
                        colore: scheme.tertiary,
                        onColore: scheme.onTertiary,
                        testo: 'To do',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una riga della superficie: una pastiglia col colore dell'elemento e il testo
/// sopra, per vedere a colpo d'occhio se si legge.
class _Riga extends StatelessWidget {
  const _Riga({
    required this.colore,
    required this.onColore,
    required this.testo,
  });

  final Color colore;
  final Color onColore;
  final String testo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: ColoredBox(
        color: colore,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            testo,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: onColore),
          ),
        ),
      ),
    );
  }
}
