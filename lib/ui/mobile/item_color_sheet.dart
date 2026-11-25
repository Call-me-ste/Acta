import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import '../shared/palette_color_row.dart';

/// La scelta del colore di un elemento, in un foglio.
class ColorChoice {
  const ColorChoice({required this.index, this.hex, this.none = false});

  final int index;
  final String? hex;
  final bool none;
}

/// Apre il foglio dei colori: sedici tinte, la tinta libera e — per un todo —
/// anche «Nessuno». Fuori dal form, dove i sedici pallini occupavano tre righe
/// prima ancora del titolo.
Future<ColorChoice?> scegliColore(
  BuildContext context, {
  required int index,
  required String? hex,
  required bool none,
  required bool allowCustom,
  required bool allowNone,
}) {
  return showActaSheet<ColorChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ColorSheet(
      index: index,
      hex: hex,
      none: none,
      allowCustom: allowCustom,
      allowNone: allowNone,
    ),
  );
}

class _ColorSheet extends StatefulWidget {
  const _ColorSheet({
    required this.index,
    required this.hex,
    required this.none,
    required this.allowCustom,
    required this.allowNone,
  });

  final int index;
  final String? hex;
  final bool none;
  final bool allowCustom;
  final bool allowNone;

  @override
  State<_ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends State<_ColorSheet> {
  late int _index = widget.index;
  late String? _hex = widget.hex;
  late bool _none = widget.none;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
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
            Text('Colore', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.l),
            PaletteColorRow(
              selectedIndex: _index,
              customHex: _hex,
              noneSelected: _none,
              onIndex: (i) => setState(() {
                _index = i;
                _hex = null;
                _none = false;
              }),
              onCustom: widget.allowCustom
                  ? (hex) => setState(() {
                        _hex = hex;
                        _none = false;
                      })
                  : null,
              onNone: widget.allowNone
                  ? () => setState(() {
                        _none = true;
                        _hex = null;
                      })
                  : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                ColorChoice(index: _index, hex: _hex, none: _none),
              ),
              child: const Text('Fatto'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il pallino del colore attivo, per la riga del form.
class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.index, this.hex, this.none = false});

  final int index;
  final String? hex;
  final bool none;

  @override
  Widget build(BuildContext context) {
    final colore = none
        ? Colors.transparent
        : ColorResolver.elementColor(
            brightness: Theme.of(context).brightness,
            index: index,
            customHex: hex,
          );
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: colore,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}
