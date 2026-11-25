import 'package:flutter/material.dart';

import '../../features/settings/app_settings_controller.dart';
import '../shared/motion.dart';
import '../shared/view_switcher_pill.dart';

/// Mese / Settimana / Giorno: una sola pillola con la pastiglia che scivola.
///
/// Le etichette sono in un posto solo (l'enum): aggiungere una vista non tocca
/// questo file, e le tre voci restano leggibili anche a testo ingrandito perché
/// la pillola cresce con la scala del testo.
class CalendarViewSwitcher extends StatelessWidget {
  const CalendarViewSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CalendarView value;
  final ValueChanged<CalendarView> onChanged;

  static const Map<CalendarView, String> _labels = {
    CalendarView.mese: 'Mese',
    CalendarView.settimana: 'Settimana',
    CalendarView.giorno: 'Giorno',
  };

  @override
  Widget build(BuildContext context) {
    // "Riduci animazioni" vale anche qui: la pastiglia si sposta, non rimbalza.
    final animate = animationsOn(context);

    return ViewSwitcherPill<CalendarView>(
      entries: [
        for (final view in CalendarView.values)
          ViewSwitcherEntry(value: view, label: _labels[view] ?? ''),
      ],
      value: value,
      onChanged: onChanged,
      animate: animate,
    );
  }
}
