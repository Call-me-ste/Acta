import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/events/event_provider.dart';
import '../../features/notifications/notification_open.dart';
import '../../features/todos/todo_provider.dart';
import 'item_detail_sheet.dart';
import 'overdue_sheet.dart';

/// Porta il tocco di un promemoria già consegnato al dettaglio dell'elemento.
class NotificationOpenGuard extends StatelessWidget {
  const NotificationOpenGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final richieste = context.watch<NotificationOpen?>();
    if (richieste?.inAttesa ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final payload = richieste!.consuma();
        if (payload != null) _apri(context, payload);
      });
    }
    return child;
  }

  void _apri(BuildContext context, String payload) {
    final parti = payload.split('@');
    final riferimento = parti.first;
    final data = parti.length > 3 ? int.tryParse(parti[3]) : null;
    final giorno =
        data == null ? null : DateTime.fromMillisecondsSinceEpoch(data);
    if (riferimento == 'riepilogo') {
      final scaduti = scadutiDaConfermare(context);
      if (scaduti.isNotEmpty) showOverdueSheet(context, scaduti);
    } else if (riferimento.startsWith('evento:')) {
      final id = riferimento.substring('evento:'.length);
      final evento = context
          .read<EventProvider>()
          .events
          .where((evento) => evento.id == id)
          .firstOrNull;
      if (evento != null) {
        showItemDetail(context, event: evento, day: giorno);
      }
    } else if (riferimento.startsWith('todo:')) {
      final id = riferimento.substring('todo:'.length);
      final todo = context
          .read<TodoProvider>()
          .todos
          .where((todo) => todo.id == id)
          .firstOrNull;
      if (todo != null) {
        showItemDetail(context, todo: todo, day: giorno);
      }
    }
  }
}
