import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// L'intestazione di una fascia dell'elenco: gli **scaduti** in cima, i
/// **completati** in fondo.
///
/// Le righe **non stanno qui**: sono fratelli nella lista, cosi' Flutter le
/// costruisce solo quando entrano nello schermo. Prima erano un `Column` dentro
/// un unico figlio della lista, e con 47 scaduti si costruivano e impaginavano
/// **tutte** a ogni ricostruzione: era il costo piu' grosso del fotogramma
/// (misurato: picco 23 ms di build con l'agenda di prova).
///
/// Lo stato aperto/chiuso sta in chi possiede la lista, perche' e' lui a
/// decidere quali righe mettere.
class TodoSectionHeader extends StatelessWidget {
  const TodoSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.count,
    required this.open,
    required this.onToggle,
    this.color,
  });

  final String title;
  final IconData icon;
  final int count;
  final bool open;
  final VoidCallback onToggle;

  /// Il colore dell'intestazione; senza, quello del tema.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colore = color ?? theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      onTap: onToggle,
      child: InkWell(
        key: ValueKey('intestazione-$title'),
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.s,
              AppSpacing.m,
              AppSpacing.s,
            ),
            child: Row(
              children: [
                Icon(icon, size: AppSpacing.icon, color: colore),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    '$title ($count)',
                    style: theme.textTheme.labelLarge?.copyWith(color: colore),
                  ),
                ),
                // La parola, non solo la freccia: «mostra»/«nascondi» dice cosa
                // succede, e chi non legge un chevron come un comando lo capisce
                // lo stesso.
                Text(
                  open ? 'Nascondi' : 'Mostra',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: AppSpacing.iconSmall,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
