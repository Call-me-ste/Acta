import '../settings/app_settings_controller.dart';
import 'calendar_warmup.dart';

/// Se il comando «Torna a oggi» deve comparire.
///
/// Sta qui, e non nel widget, perche' e' una domanda con una risposta esatta e la
/// si puo' provare con le date: **la vista sta guardando oggi?**
///
/// Serve quando il giorno scelto non e' oggi, oppure quando il periodo che si sta
/// guardando non contiene oggi (un altro mese, un'altra settimana). Guardando oggi
/// il comando non c'e': un pulsante che non serve e' solo rumore.
bool shouldOfferToday({
  required CalendarView view,
  required DateTime selectedDay,
  required DateTime focusedDay,
  required DateTime today,
}) {
  if (!sameDay(selectedDay, today)) return true;

  return switch (view) {
    CalendarView.mese =>
      focusedDay.year != today.year || focusedDay.month != today.month,
    CalendarView.settimana => !stessaSettimana(selectedDay, today),
    CalendarView.giorno => false,
  };
}

/// Lo stesso giorno del calendario, senza orario.
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Se due date cadono nella stessa settimana (che comincia di lunedi').
bool stessaSettimana(DateTime a, DateTime b) =>
    sameDay(mondayOf(a), mondayOf(b));
