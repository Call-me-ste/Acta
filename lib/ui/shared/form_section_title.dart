import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Titolo e spaziatura dei gruppi di campi.
class FormSectionTitle extends StatelessWidget {
  const FormSectionTitle(
    this.text, {
    super.key,
    this.icon,
    this.separated = false,
  });

  final String text;
  final IconData? icon;
  final bool separated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (separated)
          Divider(
              height: AppSpacing.xl, color: theme.colorScheme.outlineVariant),
        Padding(
          padding: EdgeInsets.only(
            top: separated ? AppSpacing.xs : AppSpacing.m,
            bottom: separated ? AppSpacing.s : AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: AppSpacing.iconSmall,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
