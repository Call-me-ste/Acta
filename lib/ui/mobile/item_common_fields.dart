import 'package:flutter/material.dart';

import '../../features/recurrence/domain/recurrence_label.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import '../shared/color_name.dart';
import '../shared/form_section_title.dart';
import '../shared/picker_tile.dart';
import 'category_field.dart';
import 'item_color_sheet.dart';
import 'item_recurrence_sheet.dart';
import 'item_title_field.dart';

/// I campi che eventi e todo hanno **in comune**: titolo, categorie, colore e
/// ripetizione.
///
/// Il titolo è testo, non un campo dentro un riquadro. Colore e ripetizione sono
/// **righe** che dicono il valore attuale e aprono un foglio: le sedici palline
/// e le otto chip sempre in vista erano il motivo per cui il form sembrava
/// farraginoso. La parte specifica del tipo arriva come `child` e sta in mezzo.
class ItemCommonFields extends StatelessWidget {
  const ItemCommonFields({
    super.key,
    required this.title,
    required this.colorIndex,
    required this.colorHex,
    required this.noneSelected,
    required this.rule,
    required this.anchor,
    required this.categoryIds,
    required this.onCategories,
    required this.autofocus,
    required this.onIndex,
    required this.onCustom,
    required this.onNone,
    required this.onRule,
    required this.child,
    required this.details,
  });

  final TextEditingController title;
  final int colorIndex;
  final String? colorHex;

  /// Vero per un todo senza colore (gli eventi ne hanno sempre uno: è la barra
  /// che li rappresenta nel calendario).
  final bool noneSelected;

  final RecurrenceRule? rule;
  final DateTime anchor;

  /// Le categorie scelte: da 1 a 3, e il tetto lo impone il codec degli id.
  final List<String> categoryIds;
  final ValueChanged<List<String>> onCategories;

  final bool autofocus;
  final ValueChanged<int> onIndex;
  final ValueChanged<String>? onCustom;
  final VoidCallback? onNone;
  final ValueChanged<RecurrenceRule?> onRule;

  /// La parte specifica del tipo: orari per un evento, priorità e scadenza per
  /// un todo.
  final Widget child;
  final Widget details;

  String _nomeColore(BuildContext context) {
    if (noneSelected) return 'Nessuno';
    final tinta = colorHex != null
        ? ColorResolver.hexToColor(colorHex!)
        : ColorResolver.elementColor(
            brightness: Theme.of(context).brightness,
            index: colorIndex,
          );
    return tinta == null ? 'Nessuno' : colorNameFor(tinta);
  }

  String get _riepilogoRipetizione {
    final label = recurrenceLabel(rule, anchor: anchor);
    return label.isEmpty ? 'Non si ripete' : label;
  }

  Future<void> _apriColore(BuildContext context) async {
    final scelta = await scegliColore(
      context,
      index: colorIndex,
      hex: colorHex,
      none: noneSelected,
      allowCustom: onCustom != null,
      allowNone: onNone != null,
    );
    if (scelta == null || !context.mounted) return;
    if (scelta.none) {
      onNone?.call();
      return;
    }
    if (scelta.hex != null) {
      onCustom?.call(scelta.hex!);
      return;
    }
    onIndex(scelta.index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ItemTitleField(
          controller: title,
          autofocus: autofocus,
        ),
        const SizedBox(height: AppSpacing.m),
        child,
        CategoryField(ids: categoryIds, onChanged: onCategories),
        PickerTile(
          icon: Icons.palette_outlined,
          label: 'Colore',
          value: _nomeColore(context),
          leading:
              ColorDot(index: colorIndex, hex: colorHex, none: noneSelected),
          onTap: () => _apriColore(context),
        ),
        const FormSectionTitle('Ripetizione e avvisi', separated: true),
        PickerTile(
          icon: Icons.repeat,
          label: 'Ripetizione',
          value: _riepilogoRipetizione,
          onTap: () => scegliRipetizione(
            context,
            rule: rule,
            anchor: anchor,
            onChanged: onRule,
          ),
        ),
        details,
      ],
    );
  }
}
