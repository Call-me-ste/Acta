import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../theme/design_tokens.dart';

/// L'elenco completo dei tag, con quante note li usano.
Future<String?> mostraTagSheet(
  BuildContext context, {
  required Map<String, int> counts,
  required String? selected,
}) {
  final tags = counts.keys.toList()..sort();
  final total = counts.values.fold(0, (a, b) => a + b);
  return showActaSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      Widget voce({
        required Key key,
        required String titolo,
        required int quante,
        required String valore,
      }) {
        final scelta =
            (valore == '__tutti__' && selected == null) || selected == valore;
        return ListTile(
          key: key,
          leading: const Icon(Icons.sell_outlined),
          title: Text(titolo),
          subtitle: Text('$quante note'),
          trailing: scelta
              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
              : null,
          onTap: () => Navigator.pop(ctx, valore),
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                AppSpacing.s,
              ),
              child: Text('Tag', style: theme.textTheme.titleMedium),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tags.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return voce(
                      key: const ValueKey('tag-sheet-tutti'),
                      titolo: 'Tutti i tag',
                      quante: total,
                      valore: '__tutti__',
                    );
                  }
                  if (index == 1) return const Divider(height: AppSpacing.l);
                  final tag = tags[index - 2];
                  return voce(
                    key: ValueKey('tag-sheet-$tag'),
                    titolo: '#$tag',
                    quante: counts[tag] ?? 0,
                    valore: tag,
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
