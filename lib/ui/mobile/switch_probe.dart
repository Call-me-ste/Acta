import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/settings/app_settings_controller.dart';

/// La sonda per le misure: cicla le tre viste **da sola**.
///
/// Perche' esiste: misurare i fotogrammi di un cambio vista richiede che il cambio
/// avvenga allo stesso modo ogni volta. Con i tocchi iniettati via `adb` non e'
/// cosi' (con i servizi del telefono in mezzo, i tocchi cadono a meta'): cosi'
/// invece la sequenza e' sempre quella, e nel log compaiono i marcatori
/// `PROVA inizio <vista>` e `PROVA fine` per sapere a che punto siamo.
///
/// Si accende con `--dart-define=switchProbe=true` (con
/// `--dart-define=frameLog=true` per avere anche i tempi): spenta, la costante e'
/// `const` e il ramo sparisce in compilazione.
Future<void> probeViewSwitches(BuildContext context) async {
  await Future<void>.delayed(const Duration(seconds: 4));

  for (final vista in const [
    CalendarView.settimana,
    CalendarView.giorno,
    CalendarView.mese,
    CalendarView.settimana,
    CalendarView.giorno,
  ]) {
    if (!context.mounted) return;
    debugPrint('PROVA inizio ${vista.name}');
    context.read<AppSettingsController>().setCalendarView(vista);
    // Un secondo e mezzo fra un cambio e l'altro: l'animazione (560 ms) finisce
    // con abbondanza, cosi' il blocco di fotogrammi di un cambio non si mescola
    // con il successivo.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }

  if (context.mounted) debugPrint('PROVA fine');
}
