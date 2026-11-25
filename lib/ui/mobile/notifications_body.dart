import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/notifications/notification_settings_controller.dart';
import '../../features/notifications/notification_sink.dart';
import '../shared/formatters.dart';
import 'notifications_detail.dart';
import 'notifications_prova.dart';
import 'notifications_rows.dart';

class NotificationsBody extends StatefulWidget {
  const NotificationsBody({super.key});

  @override
  State<NotificationsBody> createState() => _NotificationsBodyState();
}

class _NotificationsBodyState extends State<NotificationsBody>
    with WidgetsBindingObserver {
  bool? _permesso;
  bool? _esatto;
  int _richiestaStato = 0;
  bool _richiestaPermesso = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _leggiStatoSistema();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _leggiStatoSistema();
  }

  Future<void> _leggiStatoSistema() async {
    final richiesta = ++_richiestaStato;
    final sink = context.read<NotificationSink>();
    final permesso = await sink.permessoConcesso();
    final esatto = permesso ? await sink.puoPianificareEsatto() : null;
    if (!mounted || richiesta != _richiestaStato) return;
    if (_permesso == permesso && _esatto == esatto) return;
    setState(() {
      _permesso = permesso;
      _esatto = esatto;
    });
  }

  Future<void> _cambiaGenerale(bool acceso) async {
    final notifiche = context.read<NotificationSettingsController>();
    if (!acceso) {
      notifiche.setAttive(false);
      return;
    }
    if (_richiestaPermesso) return;

    final sink = context.read<NotificationSink>();
    setState(() => _richiestaPermesso = true);
    try {
      final permesso = await sink.chiediPermesso();
      if (!mounted) return;
      if (permesso) notifiche.setAttive(true);
      await _leggiStatoSistema();
    } finally {
      if (mounted) setState(() => _richiestaPermesso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifiche = context.watch<NotificationSettingsController>();
    final eventi = [
      if (notifiche.evento) durataNotifica(notifiche.anticipoEventi),
      if (notifiche.tuttoIlGiorno)
        'Tutto il giorno alle ${formatMinutes(notifiche.oraTuttoIlGiorno)}',
    ];
    final todo = [
      durataNotifica(notifiche.anticipoTodo),
      'senza orario alle ${formatMinutes(notifiche.oraTodo)}',
    ];
    final stile = notifiche.suono == NotificationSettingsController.suonoNessuno
        ? 'Senza suono'
        : nomeSuonoNotifica(notifiche.suono);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const ValueKey('notifica-attive'),
          contentPadding: EdgeInsets.zero,
          value: notifiche.attive,
          onChanged: _richiestaPermesso ? null : _cambiaGenerale,
          title: const Text('Avvisi'),
          subtitle: Text(
            notifiche.attive ? 'Attivi' : 'Disattivati',
          ),
        ),
        if (_permesso == false)
          RigaScelta(
            chiave: 'notifica-permesso',
            avviso: true,
            icona: Icons.notifications_off_outlined,
            titolo: 'Android non lascia arrivare gli avvisi',
            nota: 'Apri le impostazioni per consentirli',
            onTocca: context.read<NotificationSink>().apriImpostazioniNotifiche,
          )
        else if (notifiche.attive && _esatto == false)
          const RigaInformativa(
            chiave: 'notifica-esattezza',
            icona: Icons.schedule_outlined,
            titolo: 'Avvisi non puntuali',
            nota: 'Android può consegnare gli avvisi in ritardo',
          ),
        if (notifiche.attive) ...[
          const Divider(),
          RigaScelta(
            chiave: 'notifica-evento',
            icona: Icons.event_outlined,
            titolo: 'Eventi',
            nota: eventi.isEmpty ? 'Disattivati' : eventi.join(' · '),
            onTocca: () =>
                showNotificationDetail(context, NotificationDetail.events),
          ),
          RigaScelta(
            chiave: 'notifica-todo',
            icona: Icons.task_alt_outlined,
            titolo: 'To do',
            nota: notifiche.todo ? todo.join(' · ') : 'Disattivati',
            onTocca: () =>
                showNotificationDetail(context, NotificationDetail.todos),
          ),
          RigaScelta(
            chiave: 'notifica-riepilogo',
            icona: Icons.today_outlined,
            titolo: 'Riepilogo serale',
            nota: notifiche.riepilogo
                ? 'Alle ${formatMinutes(notifiche.oraRiepilogo)}'
                : 'Disattivato',
            onTocca: () =>
                showNotificationDetail(context, NotificationDetail.summary),
          ),
          RigaScelta(
            chiave: 'notifica-come-suonano',
            icona: Icons.volume_up_outlined,
            titolo: 'Stile degli avvisi',
            nota: stile,
            onTocca: () =>
                showNotificationDetail(context, NotificationDetail.style),
          ),
          const Divider(),
          const RigaProvaAvviso(),
        ],
      ],
    );
  }
}
