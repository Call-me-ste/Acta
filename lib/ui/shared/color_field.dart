import 'package:flutter/material.dart';

import 'motion.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import 'color_controls.dart';
import 'color_name.dart';
import 'color_wheel.dart';

/// Scelta di un colore: **la ruota** per tinta e saturazione, la **barra** per la
/// luminosità, i **colori pronti** per partire da qualcosa, e il codice esadecimale
/// per chi lo sa a memoria.
///
/// Prima erano tre slider (Tinta, Saturazione, Luminosità): due delle tre cose si
/// scegliono meglio in un gesto solo, e la ruota è il modo in cui tutti si
/// aspettano di scegliere un colore. Il codice resta — `#ff69b4` si scrive, ed è il
/// motivo per cui il campo esiste — e campo, ruota e barra si aggiornano a vicenda:
/// non ci sono due verità, l'anteprima è sempre il colore che verrà salvato.
class ColorField extends StatefulWidget {
  const ColorField({
    super.key,
    required this.initialHex,
    required this.onChanged,
    this.autofocus = false,
  });

  final String initialHex;

  /// Chiamata **solo** con un hex valido (`#rrggbb`): un input a metà non deve
  /// arrivare a chi salva.
  final ValueChanged<String> onChanged;

  final bool autofocus;

  @override
  State<ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<ColorField> {
  late HSLColor _hsl;

  /// La fila dei colori pronti, **una volta sola**: non dipende dal colore scelto,
  /// e ricostruirla a ogni fotogramma del trascinamento (dodici pallini, con la
  /// loro semantica) era lavoro che si vedeva nei numeri — build 8,1 ms contro 3,3
  /// degli slider che c'erano prima. Restando la **stessa istanza**, Flutter salta
  /// quel sottoalbero (è lo stesso rimedio della pagina dei todo).
  late final Widget _pronti = ColoriPronti(onScelto: _daPronto);

  @override
  void initState() {
    super.initState();
    final color =
        ColorResolver.hexToColor(widget.initialHex) ?? const Color(0xFF3F51B5);
    _hsl = HSLColor.fromColor(color);
  }

  void _daPronto(Color colore) => _fromHsl(HSLColor.fromColor(colore));

  /// Il colore cambiato dalla ruota o dalla barra: si riporta fuori, e basta.
  ///
  /// Il **codice** non c'e' piu': era una cosa da sviluppatori in mezzo a una
  /// scelta che si fa guardando, e i nomi dei colori ci sono gia'.
  void _fromHsl(HSLColor hsl) {
    setState(() => _hsl = hsl);
    widget.onChanged(ColorResolver.colorToHex(hsl.toColor()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _hsl.toColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: current,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                colorNameFor(current),
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        ColorWheel(
          hue: _hsl.hue.isNaN ? 0 : _hsl.hue,
          saturation: _hsl.saturation,
          lightness: _hsl.lightness,
          onChanged: (tinta, saturazione) => _fromHsl(
            _hsl.withHue(tinta).withSaturation(saturazione),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        Text('Luminosità', style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        BarraLuminosita(
          hue: _hsl.hue.isNaN ? 0 : _hsl.hue,
          saturation: _hsl.saturation,
          lightness: _hsl.lightness,
          onChanged: (valore) => _fromHsl(_hsl.withLightness(valore)),
        ),
        const SizedBox(height: AppSpacing.m),
        Text('Colori pronti', style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        _pronti,
      ],
    );
  }
}

/// Apre il selettore e restituisce l'hex scelto, o `null` se si annulla.
Future<String?> showColorDialog(
  BuildContext context, {
  required String initialHex,
  String title = 'Colore personalizzato',
}) {
  var chosen = initialHex;
  return showActaDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: ColorField(
            initialHex: initialHex,
            onChanged: (hex) => chosen = hex,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, chosen),
          child: const Text('Usa questo'),
        ),
      ],
    ),
  );
}
