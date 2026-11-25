import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/settings/app_settings_controller.dart';
import '../shared/scelta_sheet.dart';

/// «Todo nel calendario»: **una riga** che dice com'è impostato, e le tre scelte
/// in un foglio.
///
/// Erano tre righe radio con tre paragrafi — un terzo della pagina delle
/// impostazioni per una preferenza che si tocca una volta nella vita — e chi non
/// sapeva cosa volesse dire «Piena» lo scopriva solo scegliendola. Adesso la riga
/// dice il valore attuale, e le spiegazioni stanno nel foglio: là servono, qui
/// erano rumore.
///
/// Le regole restano quelle: `nascosta` non tocca la scheda Todo, il foglio degli
/// scaduti né i promemoria (vedi `TodoInCalendario` in
/// `features/settings/app_settings_controller.dart`).
class TodoInCalendarRow extends StatelessWidget {
  const TodoInCalendarRow({super.key});

  /// Le tre modalità con le loro spiegazioni: la riga usa il **titolo** di quella
  /// attiva, il foglio le mostra tutte e tre.
  static const List<(TodoInCalendario, String, String)> voci = [
    (
      TodoInCalendario.compatta,
      'Compatta',
      'In fondo al calendario, in una fascia che si apre col tocco',
    ),
    (
      TodoInCalendario.nascosta,
      'Nascosta',
      'Solo nella scheda To do: il calendario resta agli eventi',
    ),
    (
      TodoInCalendario.pieni,
      'Pieni',
      'Come righe dentro la giornata, con il loro orario',
    ),
  ];

  /// Il titolo della modalità scelta («Compatta», «Nascosta», «Pieni»).
  static String titoloDi(TodoInCalendario modo) =>
      voci.firstWhere((voce) => voce.$1 == modo).$2;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();

    return ListTile(
      key: const ValueKey('todo-nel-calendario'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.checklist_outlined),
      title: const Text('To do nel calendario'),
      subtitle: Text(titoloDi(settings.todoInCalendario)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _scegli(context, settings),
    );
  }

  Future<void> _scegli(
    BuildContext context,
    AppSettingsController settings,
  ) async {
    final scelto = await mostraSceltaAzione(
      context,
      titolo: 'To do nel calendario',
      voci: [
        for (final (modo, titolo, spiegazione) in voci)
          (valore: modo.name, etichetta: titolo, nota: spiegazione),
      ],
    );
    if (scelto == null) return;

    for (final modo in TodoInCalendario.values) {
      if (modo.name == scelto) settings.setTodoInCalendario(modo);
    }
  }
}
