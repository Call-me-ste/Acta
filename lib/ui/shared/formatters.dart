/// Formattazione di date e orari per la UI, in un solo posto.
///
/// Prima ogni pagina aveva la propria copia di `_formatTime`/`_formatDate`/
/// `_formatTimeRange`: è il tipo di duplicazione che in v2 è finita in file da
/// migliaia di righe.
library;

String formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Un'ora del giorno scritta in **minuti dalla mezzanotte** (`1320` → `22:00`).
///
/// Le preferenze delle notifiche salvano così (un intero si confronta e si
/// ordina, un'ora no), e questa è l'unica conversione verso il testo: la usano
/// la sezione delle impostazioni e i sottotitoli dei quattro tipi di avviso.
String formatMinutes(int minuti) {
  final ore = (minuti ~/ 60).toString().padLeft(2, '0');
  final resto = (minuti % 60).toString().padLeft(2, '0');
  return '$ore:$resto';
}

String formatTimeRange(DateTime start, DateTime end) {
  return '${formatTime(start)} - ${formatTime(end)}';
}

String formatDay(DateTime day) => '${day.day}/${day.month}/${day.year}';

String formatShortDay(DateTime day) => '${day.day}/${day.month}';

/// I sette giorni in forma **breve**, in italiano come il resto dell'app: l'app
/// parla italiano a prescindere dalla lingua del sistema (decisione del locale),
/// e tre lettere ci stanno anche col testo ingrandito.
const Map<int, String> giorniBrevi = {
  DateTime.monday: 'lun',
  DateTime.tuesday: 'mar',
  DateTime.wednesday: 'mer',
  DateTime.thursday: 'gio',
  DateTime.friday: 'ven',
  DateTime.saturday: 'sab',
  DateTime.sunday: 'dom',
};

String giornoBreve(int weekday) => giorniBrevi[weekday] ?? '';

/// I dodici mesi in forma **breve** (`gen`, `feb`, …).
///
/// Una mappa costante e non `DateFormat`: la usano anche i **widget**, il cui
/// disegno gira in un processo che non ha caricato il locale di `intl` (il
/// `initializeDateFormatting` dell'avvio non c'e'), e una data che cambia lingua
/// a seconda di chi la chiede e' peggio di dodici stringhe scritte a mano.
const Map<int, String> mesiBrevi = {
  1: 'gen',
  2: 'feb',
  3: 'mar',
  4: 'apr',
  5: 'mag',
  6: 'giu',
  7: 'lug',
  8: 'ago',
  9: 'set',
  10: 'ott',
  11: 'nov',
  12: 'dic',
};

String meseBreve(int month) => mesiBrevi[month] ?? '';

/// I dodici mesi in forma **piena** (`settembre`): l'intestazione del widget
/// mensile. Stessa ragione delle forme brevi (processo del launcher, niente
/// `intl`).
const Map<int, String> mesiLunghi = {
  1: 'gennaio',
  2: 'febbraio',
  3: 'marzo',
  4: 'aprile',
  5: 'maggio',
  6: 'giugno',
  7: 'luglio',
  8: 'agosto',
  9: 'settembre',
  10: 'ottobre',
  11: 'novembre',
  12: 'dicembre',
};

String meseLungo(int month) => mesiLunghi[month] ?? '';

/// L'intestazione del widget mensile: `settembre 2026`.
String meseAnno(DateTime mese) => '${meseLungo(mese.month)} ${mese.year}';

/// Una data come la legge un widget: `gio 24 set`.
String dataBreve(DateTime giorno) =>
    '${giornoBreve(giorno.weekday)} ${giorno.day} ${meseBreve(giorno.month)}';
