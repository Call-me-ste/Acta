import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Intestazione di pagina: una sola griglia per tutte le schermate.
///
/// Titolo a [AppSpacing.page] dal bordo, azioni a [AppSpacing.s]: è la stessa
/// distanza che hanno i contenuti sotto, così icone e testo non sembrano
/// appoggiati a caso.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s,
        AppSpacing.s,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
