import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Riga "etichetta + valore" che apre un selettore (data, ora, posizione, …).
///
/// Tutti i campi condividono altezza minima, colonna dell'icona e corpo del
/// testo. Etichette e valori possono andare a capo.
class PickerTile extends StatelessWidget {
  const PickerTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.note,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  /// Segno al posto dell'icona (per esempio il pallino del colore): se c'è,
  /// prende il posto dell'icona, non la affianca.
  final Widget? leading;

  /// Riga piccola sotto il valore: dice **perché** quel valore è quello, per
  /// esempio «Predefinito delle impostazioni». Non è una seconda etichetta.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: AppSpacing.icon,
                    child: Center(
                      child: leading ??
                          Icon(
                            icon,
                            size: AppSpacing.icon,
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right,
                    size: AppSpacing.iconSmall,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.rowText,
                    top: AppSpacing.xs,
                  ),
                  child: Text(
                    note!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
