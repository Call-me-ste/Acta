import 'package:flutter/material.dart';

import '../../features/events/domain/event_occurrence.dart';
import '../../features/recurrence/domain/recurrence_label.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../shared/event_colors.dart';
import '../shared/formatters.dart';

/// Una riga della lista eventi (vista mese e vista giorno la usano uguale).
///
/// La ricorrenza si legge a schermo — "ogni lun-ven" invece di una data che
/// sembra l'unica volta — ed è l'unica cosa che distingue un evento singolo da
/// una serie, quindi sta nel sottotitolo e non in un'icona.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.occurrence, this.onTap});

  final EventOccurrence occurrence;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = recurrenceLabel(
      RecurrenceRule.tryParse(occurrence.event.recurrenceRule),
      anchor: occurrence.event.start,
    );
    // Un evento senza orario non ha un orario da mostrare: "00:00 – 23:59"
    // sarebbe rumore.
    final time = occurrence.event.allDay
        ? 'Tutto il giorno'
        : formatTimeRange(occurrence.start, occurrence.end);

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: occurrenceColor(context, occurrence),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(occurrence.title),
      subtitle: Text(label.isEmpty ? time : '$time · $label'),
    );
  }
}
