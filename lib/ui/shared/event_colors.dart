import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/events/domain/event_occurrence.dart';
import '../../features/palette/domain/palette.dart';
import '../../features/palette/palette_controller.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../theme/color_resolver.dart';

/// La palette attiva su questo device.
///
/// Un solo punto di verità: le pagine non conoscono `ColorResolver` né gli id
/// delle palette, chiedono il colore e basta. Cambiare palette si vede subito
/// ovunque perché tutti passano da qui.
Palette activePalette(BuildContext context) {
  final settings = context.watch<AppSettingsController>();
  return context.watch<PaletteController>().resolve(settings.activePaletteId);
}

/// Il colore di un'occorrenza: l'hex scelto a mano vince sull'indice nella
/// palette, e in tema scuro la tinta si schiarisce.
Color occurrenceColor(BuildContext context, EventOccurrence occurrence) {
  return ColorResolver.elementColor(
    palette: activePalette(context),
    brightness: Theme.of(context).brightness,
    index: occurrence.colorIndex,
    customHex: occurrence.event.colorHex,
  );
}

/// Il colore di un todo, o `null` se non ne ha uno: un todo senza colore resta
/// neutro, non prende il primo della palette.
Color? todoColor(BuildContext context, int? index) {
  if (index == null) return null;
  return ColorResolver.elementColor(
    palette: activePalette(context),
    brightness: Theme.of(context).brightness,
    index: index,
  );
}
