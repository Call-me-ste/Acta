import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../theme/design_tokens.dart';
import '../shared/recurrence_field.dart';

/// La scelta della ripetizione in un foglio: dentro c'è il campo di sempre
/// (`RecurrenceField`), ma il form resta a righe e non mostra otto chip.
Future<void> scegliRipetizione(
  BuildContext context, {
  required RecurrenceRule? rule,
  required DateTime anchor,
  required ValueChanged<RecurrenceRule?> onChanged,
}) {
  return showActaSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.l,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ripetizione', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.s),
                RecurrenceField(
                  rule: rule,
                  anchor: anchor,
                  onChanged: onChanged,
                  showTitle: false,
                  closeOnSelect: true,
                ),
                const SizedBox(height: AppSpacing.m),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fatto'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
