import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../theme/design_tokens.dart';
import '../shared/priority_style.dart';

/// Una voce di un foglio di scelta: valore, etichetta, eventuale nota e segno.
class PickerSheetEntry<T> {
  const PickerSheetEntry({
    required this.value,
    required this.label,
    this.note,
    this.leading,
  });

  final T value;
  final String label;
  final String? note;
  final Widget? leading;
}

/// Foglio di scelta a elenco: una riga per voce, spunta su quella attiva.
///
/// È il sostituto delle file di chip nel form: una scelta = una riga che dice
/// **cosa succede**, non una pastiglia che dice **come si chiama** il meccanismo.
Future<T?> showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<PickerSheetEntry<T>> entries,
  T? selected,
}) {
  return showActaSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
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
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (_, index) {
                  final voce = entries[index];
                  final scelta = voce.value == selected;
                  return ListTile(
                    leading: voce.leading,
                    title: Text(voce.label),
                    subtitle: voce.note == null ? null : Text(voce.note!),
                    trailing: scelta
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(ctx, voce.value),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.s),
          ],
        ),
      );
    },
  );
}

/// La priorità: quattro righe con il pallino del livello. Sostituisce i quattro
/// chip che andavano a capo 3+1 su metà dei telefoni.
Future<int?> scegliPriorita(BuildContext context, int corrente) {
  // `read`, non `watch`: qui siamo dentro un callback, fuori dal build.
  final colori = context.read<AppSettingsController>().priorityColors;
  return showPickerSheet<int>(
    context: context,
    title: 'Priorità',
    selected: corrente,
    entries: [
      for (var i = 0; i < priorityLabels.length; i++)
        PickerSheetEntry(
          value: i,
          label: priorityLabels[i],
          leading: Icon(
            priorityIcon(i),
            color: priorityColorFrom(colori, i),
          ),
        ),
    ],
  );
}
