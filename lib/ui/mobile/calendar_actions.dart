import 'package:flutter/material.dart';

import '../../features/calendar/calendar_focus.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../theme/design_tokens.dart';
import 'back_to_today_button.dart';
import 'item_search_page.dart';

/// Ricerca e aggiunta in basso a destra. «Torna a oggi» compare accanto al «＋».
///
/// Stanno in un file loro per il tetto delle 300 righe di `calendar_page.dart`, e
/// perché sono una cosa sola: l'angolo dei comandi.
///
/// Forma e colori: il «＋» è un FAB **tondo**, come la pillola che sceglie la
/// vista. La parola «Nuovo» se n'è andata: era larga e copriva l'ultima riga
/// del calendario. Il nome resta nel tooltip e nella semantica, per chi usa il
/// lettore di schermo.
class CalendarActions extends StatelessWidget {
  const CalendarActions({
    super.key,
    required this.mostrato,
    required this.today,
    required this.onToday,
    required this.onNew,
    required this.onOpenDay,
  });

  /// Le azioni **cosi' come le vuole il calendario**: la regola di quando
  /// offrire «torna a oggi» sta qui, con il widget, e la pagina dice solo cosa
  /// fare. Sta qui anche per il tetto di righe di `calendar_page.dart`.
  static Widget perLaPagina({
    required CalendarView view,
    required DateTime selectedDay,
    required DateTime focusedDay,
    required DateTime now,
    required ValueChanged<DateTime> onToday,
    required VoidCallback onNew,
    required ValueChanged<DateTime> onOpenDay,
  }) =>
      CalendarActions(
        mostrato: shouldOfferToday(
          view: view,
          selectedDay: selectedDay,
          focusedDay: focusedDay,
          today: now,
        ),
        today: now,
        onToday: () => onToday(now),
        onNew: onNew,
        onOpenDay: onOpenDay,
      );

  /// Se il ritorno a oggi va mostrato: guardando oggi non occupa spazio.
  final bool mostrato;

  /// Il giorno verso cui riporta, per l'etichetta «Oggi 17 set».
  final DateTime today;

  final VoidCallback onToday;
  final VoidCallback onNew;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (mostrato) ...[
          BackToTodayButton(onPressed: onToday, today: today),
          const SizedBox(width: AppSpacing.s),
        ],
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ItemSearchButton(onOpenDay: onOpenDay),
            FloatingActionButton(
              onPressed: onNew,
              tooltip: 'Nuovo',
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
