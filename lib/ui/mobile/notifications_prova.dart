import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/notifications/domain/reminder_plan.dart';
import '../../features/notifications/notification_settings_controller.dart';
import '../../features/notifications/notification_sink.dart';
import 'notifications_rows.dart';

/// L'id dell'**avviso di prova**: uno solo, sempre lo stesso (chiederlo due volte
/// sostituisce quello di prima invece di accumularne), e scelto in una banda che
/// gli id veri non toccano — nascono da un hash a 31 bit e stanno sotto il
/// miliardo.
const int idAvvisoDiProva = 2000000001;

/// La riga **«Prova: mandami un avviso fra un minuto»**.
///
/// Serve a una domanda sola, che è quella di tutti: *funziona?* Chi non sa se la
/// catena è a posto non deve aspettare che scada un todo o che cominci un evento
/// — e non deve credere sulla parola.
///
/// Non è un'impostazione: non resta, non si riprogramma, e il prossimo giro di
/// riconciliazione la cancella (cioè dopo che è già scattata).
class RigaProvaAvviso extends StatelessWidget {
  const RigaProvaAvviso({super.key});

  @override
  Widget build(BuildContext context) {
    return RigaScelta(
      chiave: 'notifica-prova',
      icona: Icons.play_circle_outline,
      titolo: 'Invia un avviso di prova',
      nota: 'Arriva fra un minuto',
      freccia: false,
      onTocca: () => _prova(context),
    );
  }

  Future<void> _prova(BuildContext context) async {
    final notifiche = context.read<NotificationSettingsController>();
    final sink = context.read<NotificationSink>();
    final quando = DateTime.now().add(const Duration(minutes: 1));
    final ore = notifiche.quietHours;

    await sink.pianifica(
      ScheduledReminder(
        id: idAvvisoDiProva,
        itemId: 'prova',
        when: quando,
        title: 'Avviso di prova',
        kind: ReminderKind.evento,
        // Suona come suonerebbe un evento vero a quest'ora: dentro le ore
        // silenziose la prova è **muta**, ed è la verità — non una promessa.
        sound: notifiche.suona,
        quiet: ore != null && isQuiet(quando, ore),
      ),
      notifiche,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Arriva fra un minuto')));
  }
}
