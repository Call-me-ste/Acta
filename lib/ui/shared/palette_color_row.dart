import 'package:flutter/material.dart';

import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import '../../theme/event_palette.dart';
import 'color_field.dart';

/// La riga dei colori di una palette, con le due eccezioni che servono davvero:
///
/// * **personalizzato** (`onCustom`): un colore fuori palette, scelto a mano;
/// * **nessuno** (`onNone`): il todo resta neutro.
///
/// È lo stesso widget per eventi e todo: due righe di colori diverse nella stessa
/// app sarebbero due cose da mantenere e due comportamenti da spiegare.
class PaletteColorRow extends StatelessWidget {
  const PaletteColorRow({
    super.key,
    required this.selectedIndex,
    required this.onIndex,
    this.customHex,
    this.onCustom,
    this.onNone,
    this.noneSelected = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onIndex;

  /// Colore scelto a mano: se c'è, vince sulla palette e la selezione si sposta
  /// sulla pastiglia "personalizzato".
  final String? customHex;

  final ValueChanged<String>? onCustom;
  final VoidCallback? onNone;

  /// La voce "Nessuno" è quella scelta (un todo senza colore).
  final bool noneSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final custom = customHex != null;

    return Wrap(
      spacing: AppSpacing.m,
      runSpacing: AppSpacing.m,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < EventPalette.length; i++)
          _Swatch(
            key: ValueKey('event-color-$i'),
            color: ColorResolver.elementColor(
              brightness: brightness,
              index: i,
            ),
            selected: !custom && i == selectedIndex,
            onTap: () => onIndex(i),
          ),
        if (onCustom != null)
          _Swatch(
            key: const ValueKey('event-color-custom'),
            color: custom
                ? ColorResolver.elementColor(
                    brightness: brightness,
                    customHex: customHex,
                  )
                : null,
            selected: custom,
            icon: Icons.edit_outlined,
            onTap: () async {
              final hex = await showColorDialog(
                context,
                initialHex: customHex ?? EventPalette.at(selectedIndex),
              );
              if (hex != null) onCustom!(hex);
            },
          ),
        if (custom && onNone != null)
          TextButton(
            onPressed: onNone,
            child: const Text('Torna alla palette'),
          ),
        if (onNone != null && !custom)
          ChoiceChip(
            label: const Text('Nessuno'),
            selected: noneSelected,
            onSelected: (_) => onNone!(),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
  });

  /// `null` = pastiglia senza colore scelto (il "personalizzato" vuoto): si
  /// disegna l'icona, non un colore inventato.
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      // Il pallino è 40 e l'anello attorno ne fa 48: il bersaglio toccabile che
      // le linee guida chiedono, senza pallini giganti.
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Container(
          width: AppSpacing.touchTarget - AppSpacing.xs * 2,
          height: AppSpacing.touchTarget - AppSpacing.xs * 2,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: icon == null
              ? null
              : Icon(
                  icon,
                  size: AppSpacing.iconSmall,
                  color: color == null
                      ? theme.colorScheme.onSurfaceVariant
                      : ColorResolver.onColor(color!),
                ),
        ),
      ),
    );
  }
}
