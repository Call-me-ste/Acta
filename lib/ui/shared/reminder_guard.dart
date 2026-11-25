import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/database_service.dart';
import '../../features/events/event_provider.dart';
import '../../features/notifications/notification_actions.dart';
import '../../features/notifications/notification_scheduler.dart';
import '../../features/notifications/notification_settings_controller.dart';
import '../../features/todos/todo_provider.dart';

/// I momenti in cui gli avvisi vanno **ricalcolati**: quando l'app si apre e
/// quando torna in primo piano. Più le modifiche, che arrivano dagli ascolti qui
/// sotto.
///
/// Un widget e non del codice dentro `main.dart` per lo stesso motivo di
/// `BackupGuard`: così si può provare. E perché quello che fa non si vede — un
/// avviso che manca si scopre il giorno in cui serviva.
///
/// **Perché gli ascolti stanno qui e non nei provider**: chi scrive un todo non
/// deve sapere che esistono le notifiche. Questo è l'unico posto che sa due
/// cose: che i todo e gli eventi cambiano, e che c'è un pianificatore da
/// avvisare. Il pianificatore ha il suo debounce, quindi tre scritture di fila
/// fanno un giro solo.
class ReminderGuard extends StatefulWidget {
  const ReminderGuard({super.key, required this.child});

  final Widget child;

  @override
  State<ReminderGuard> createState() => _ReminderGuardState();
}

class _ReminderGuardState extends State<ReminderGuard>
    with WidgetsBindingObserver {
  EventProvider? _eventi;
  TodoProvider? _todo;
  NotificationSettingsController? _notifiche;
  bool _agganciato = false;
  DatabaseService? _db;
  String? _ultimaSpuntaDaNotifica;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Dopo il primo fotogramma: l'avvio non deve aspettare il sistema operativo, e
    // a quel punto le preferenze e il database sono già letti.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationScheduler>().riconcilia();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_agganciato) return;
    _agganciato = true;
    _db = context.read<DatabaseService?>();
    _ultimaSpuntaDaNotifica = _db?.meta.get(notificationCompletionClock);

    // Chi, cambiando, cambia gli avvisi: gli eventi, i todo, e le impostazioni
    // (accendere un tipo pianifica, spegnerlo annulla).
    _eventi = context.read<EventProvider>()..addListener(_qualcosaECambiato);
    _todo = context.read<TodoProvider>()..addListener(_qualcosaECambiato);
    _notifiche = context.read<NotificationSettingsController>()
      ..addListener(_qualcosaECambiato);
  }

  /// Una scrittura qualsiasi: si chiede un giro, **fra poco** (il debounce è del
  /// pianificatore).
  void _qualcosaECambiato() {
    if (!mounted) return;
    context.read<NotificationScheduler>().programma();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tornando in primo piano la finestra può essersi mossa (giorni passati,
    // avvisi scattati): si ricalcola subito, senza aspettare una modifica.
    if (state != AppLifecycleState.resumed || !mounted) return;
    final spunta = _db?.meta.get(notificationCompletionClock);
    if (spunta != _ultimaSpuntaDaNotifica) {
      _ultimaSpuntaDaNotifica = spunta;
      _todo?.reload();
    }
    context.read<NotificationScheduler>().riconcilia();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventi?.removeListener(_qualcosaECambiato);
    _todo?.removeListener(_qualcosaECambiato);
    _notifiche?.removeListener(_qualcosaECambiato);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
