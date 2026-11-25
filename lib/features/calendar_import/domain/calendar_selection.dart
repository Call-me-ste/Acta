import 'device_calendar_gateway.dart';

/// Le regole della **selezione intelligente** dei calendari.
///
/// Android espone tutto quello che c'è nell'account: calendari personali,
/// festività, compleanni, anniversari e calendari tecnici del produttore. In un
/// import one-click questi ultimi sono rumore: restano disponibili, ma in una
/// sezione chiusa e mai preselezionati.
bool isSystemCalendar(DeviceCalendarInfo calendar) {
  if (calendar.hidden) return true;
  final nome = calendar.name.toLowerCase();
  return nome.contains('festivit') ||
      nome.contains('holiday') ||
      nome.contains('compleann') ||
      nome.contains('birthday') ||
      nome.contains('anniversar') ||
      nome.contains('countdown') ||
      nome.contains('onomastic') ||
      nome.contains('santo') ||
      nome.contains('saints') ||
      nome.startsWith('oplus_');
}

bool isLocalCalendar(DeviceCalendarInfo calendar) {
  final nome = calendar.name.toLowerCase();
  final account = calendar.accountName?.toLowerCase();
  final tipo = calendar.accountType?.toLowerCase();
  return nome == 'local account' ||
      account == 'local account' ||
      tipo == 'local' ||
      tipo == 'com.android.calendar' ||
      nome == 'phone' ||
      nome == 'my calendar' ||
      nome == 'calendario locale';
}

String calendarName(DeviceCalendarInfo calendar) {
  if (isLocalCalendar(calendar)) return 'Calendario locale';
  return calendar.name;
}

/// Identità **per la UI**: due calendari con lo stesso nome e lo stesso account
/// sono lo stesso gruppo (Samsung/OnePlus a volte duplicano la riga). Il
/// calendario locale viene normalizzato a un’unica identità.
String calendarGroupKey(DeviceCalendarInfo calendar) {
  final nome = calendarName(calendar).trim().toLowerCase();
  if (isLocalCalendar(calendar)) return 'local|$nome';
  final account = (calendar.accountName ?? calendar.accountType ?? calendar.id)
      .trim()
      .toLowerCase();
  return '$nome|$account';
}

String? calendarSubtitle(DeviceCalendarInfo calendar) {
  final parti = <String>[];
  if (isLocalCalendar(calendar)) {
    parti.add('Eventi salvati solo su questo telefono');
  } else if ((calendar.accountName ?? '').trim().isNotEmpty &&
      calendar.accountName != calendar.name) {
    parti.add(calendar.accountName!.trim());
  }
  if (calendar.readOnly) parti.add('sola lettura');
  return parti.isEmpty ? null : parti.join(' · ');
}

/// Cosa selezionare appena si apre la pagina.
///
/// Prima i calendari principali scrivibili: sono quelli su cui il telefono
/// scrive di default. Se il sistema non espone il flag, si prendono tutti i
/// calendari personali scrivibili. Festività, compleanni, anniversari e
/// calendari in sola lettura restano fuori.
List<DeviceCalendarInfo> defaultCalendars(
  List<DeviceCalendarInfo> calendars,
) {
  final candidati = [
    for (final calendar in calendars)
      if (!calendar.readOnly && !isSystemCalendar(calendar)) calendar,
  ];
  final principali = [
    for (final calendar in candidati)
      if (calendar.isPrimary) calendar,
  ];
  if (principali.isNotEmpty) {
    final gruppi = {
      for (final calendar in principali) calendarGroupKey(calendar)
    };
    return [
      for (final calendar in candidati)
        if (gruppi.contains(calendarGroupKey(calendar))) calendar,
    ];
  }

  // Android non sempre espone `isPrimary`: in quel caso si prende **un
  // gruppo per account**, preferendo quello che porta il nome dell'account
  // (il calendario principale di Google). Gli altri restano a un tocco.
  final perAccount = <String, String>{};
  final ordinati = [...candidati]..sort(compareCalendars);
  for (final calendar in ordinati) {
    final account = isLocalCalendar(calendar)
        ? 'local'
        : (calendar.accountName ?? calendar.accountType ?? calendar.id)
            .trim()
            .toLowerCase();
    final gruppo = calendarGroupKey(calendar);
    final esistente = perAccount[account];
    if (esistente == null || calendar.name == calendar.accountName) {
      perAccount[account] = gruppo;
    }
  }
  final gruppi = perAccount.values.toSet();
  return [
    for (final calendar in candidati)
      if (gruppi.contains(calendarGroupKey(calendar))) calendar,
  ];
}

/// Ordine di lettura: prima i principali, poi per nome.
int compareCalendars(DeviceCalendarInfo a, DeviceCalendarInfo b) {
  if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
  return calendarName(a).toLowerCase().compareTo(
        calendarName(b).toLowerCase(),
      );
}
