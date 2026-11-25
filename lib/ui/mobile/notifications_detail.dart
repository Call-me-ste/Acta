import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/notifications/notification_settings_controller.dart';
import '../../features/notifications/notification_sink.dart';
import '../../theme/design_tokens.dart';
import '../shared/formatters.dart';
import '../shared/motion.dart';
import 'notifications_rows.dart';
import 'notifications_sheets.dart';

enum NotificationDetail {
  events('Eventi'),
  todos('To do'),
  summary('Riepilogo serale'),
  style('Stile degli avvisi');

  const NotificationDetail(this.titolo);
  final String titolo;
}

Future<void> showNotificationDetail(
  BuildContext context,
  NotificationDetail detail,
) {
  final controller = context.read<NotificationSettingsController>();
  final sink = context.read<NotificationSink>();

  return showActaSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints:
        BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
    builder: (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final righe = _righe(context, detail, controller, sink);
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.l, 0, AppSpacing.l, AppSpacing.l),
            itemCount: righe.length + 1,
            itemBuilder: (context, index) => index == 0
                ? Text(detail.titolo,
                    style: Theme.of(context).textTheme.titleMedium)
                : righe[index - 1],
          ),
        );
      },
    ),
  );
}

List<Widget> _righe(
  BuildContext context,
  NotificationDetail detail,
  NotificationSettingsController notifiche,
  NotificationSink sink,
) =>
    switch (detail) {
      NotificationDetail.events => [
          SwitchListTile(
            key: const ValueKey('notifica-eventi-con-orario'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Eventi con orario'),
            value: notifiche.evento,
            onChanged: notifiche.setEvento,
          ),
          if (notifiche.evento)
            _anticipo(context, 'notifica-anticipo-evento',
                notifiche.anticipoEventi, notifiche.setAnticipoEventi),
          const Divider(),
          SwitchListTile(
            key: const ValueKey('notifica-tutto-il-giorno'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Eventi tutto il giorno'),
            value: notifiche.tuttoIlGiorno,
            onChanged: notifiche.setTuttoIlGiorno,
          ),
          if (notifiche.tuttoIlGiorno)
            RigaOra(
              chiave: 'notifica-ora-tutto-il-giorno',
              titolo: 'Ora del promemoria',
              minuti: notifiche.oraTuttoIlGiorno,
              onCambia: notifiche.setOraTuttoIlGiorno,
            ),
        ],
      NotificationDetail.todos => [
          SwitchListTile(
            key: const ValueKey('notifica-todo-attivo'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Avvisa alla scadenza'),
            value: notifiche.todo,
            onChanged: notifiche.setTodo,
          ),
          if (notifiche.todo) ...[
            _anticipo(context, 'notifica-anticipo-todo', notifiche.anticipoTodo,
                notifiche.setAnticipoTodo),
            RigaOra(
              chiave: 'notifica-ora-todo',
              titolo: 'Ora per i To do senza orario',
              minuti: notifiche.oraTodo,
              onCambia: notifiche.setOraTodo,
            ),
          ],
        ],
      NotificationDetail.summary => [
          TipoAvviso(
            chiave: 'notifica-riepilogo-attivo',
            titolo: 'Riepilogo a fine giornata',
            nota: 'Avvisa se ci sono scadenze da confermare',
            valore: notifiche.riepilogo,
            onCambia: notifiche.setRiepilogo,
          ),
          if (notifiche.riepilogo)
            RigaOra(
              chiave: 'notifica-ora-riepilogo',
              titolo: 'Ora del riepilogo',
              minuti: notifiche.oraRiepilogo,
              onCambia: notifiche.setOraRiepilogo,
            ),
        ],
      NotificationDetail.style => [
          RigaScelta(
            chiave: 'notifica-suono',
            titolo: 'Suono',
            nota: nomeSuonoNotifica(notifiche.suono),
            onTocca: () => mostraSceltaSuono(context, notifiche),
          ),
          SwitchListTile(
            key: const ValueKey('notifica-vibra-evento'),
            contentPadding: EdgeInsets.zero,
            value: notifiche.vibraEventi,
            onChanged: notifiche.setVibraEventi,
            title: const Text('Vibrazione per gli eventi'),
          ),
          SwitchListTile(
            key: const ValueKey('notifica-vibra-todo'),
            contentPadding: EdgeInsets.zero,
            value: notifiche.vibraTodo,
            onChanged: notifiche.setVibraTodo,
            title: const Text('Vibrazione per i To do'),
          ),
          RigaScelta(
            chiave: 'notifica-blocco',
            titolo: 'Schermata di blocco',
            nota: nomeBloccoNotifica(notifiche.blocco),
            onTocca: () => mostraSceltaBlocco(context, notifiche),
          ),
          RigaScelta(
            chiave: 'notifica-silenzio',
            titolo: 'Ore silenziose',
            nota: notifiche.quietHours == null
                ? 'Nessuna'
                : 'Dalle ${formatMinutes(notifiche.silenzioDa)} '
                    'alle ${formatMinutes(notifiche.silenzioA)}',
            onTocca: () => mostraFoglioSilenzio(context, notifiche),
          ),
          const Divider(),
          RigaScelta(
            chiave: 'notifica-sistema',
            titolo: 'Impostazioni di Android',
            nota: 'Gestisci gli avvisi di Acta sul telefono',
            onTocca: sink.apriImpostazioniNotifiche,
          ),
        ],
    };

Widget _anticipo(
  BuildContext context,
  String chiave,
  int valore,
  ValueChanged<int> onScelta,
) =>
    RigaScelta(
      chiave: chiave,
      titolo: 'Quando avvisare',
      nota: durataNotifica(valore),
      onTocca: () => mostraSceltaAnticipo(
        context,
        titolo: 'Quando avvisare',
        attuale: valore,
        onScelta: onScelta,
      ),
    );
