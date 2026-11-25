import 'dart:ui' show Offset, Rect;

/// Dove cade ogni giorno nella griglia del mese.
///
/// La stessa aritmetica serve a tre cose: **disegnare** le celle, capire quale
/// giorno sta **sotto un dito**, e **verificarlo** in un test. Sta fuori dai
/// widget (nessun import di Material) perche' e' geometria, non disegno.
///
/// Riproduce quello che faceva `table_calendar` con `startingDayOfWeek: sunday`:
/// la griglia comincia dalla domenica della settimana che contiene il primo del
/// mese, e ha **cinque o sei righe** a seconda di come cade il mese — non un
/// numero fisso.
class MonthGridGeometry {
  MonthGridGeometry({
    required DateTime month,
    this.cellWidth = 0,
    this.rowHeight = 0,
    this.headerHeight = 0,
  }) : mese = DateTime(month.year, month.month);

  /// Un giorno qualunque del mese mostrato: servono solo anno e mese.
  final DateTime mese;

  /// Quanto e' larga una cella (la griglia e' larga quanto lo schermo, diviso
  /// sette).
  ///
  /// Le tre misure hanno zero come default: chi ha bisogno **solo dei giorni**
  /// (il precaricamento delle celle, che conta 35 o 42 e non disegna) le lascia
  /// fuori, e i paragrafi non dipendono da quanto e' alta una riga.
  final double cellWidth;

  /// Quanto e' alta una riga di giorni.
  final double rowHeight;

  /// Quanto e' alta la riga dei nomi (`dom lun mar…`).
  final double headerHeight;

  static const int colonne = 7;

  /// Il primo giorno mostrato: la **domenica** della settimana che contiene il
  /// primo del mese. `DateTime.sunday` vale 7, quindi `weekday % 7` da' 0 alla
  /// domenica e 6 al sabato.
  late final DateTime primo = () {
    final first = DateTime(mese.year, mese.month, 1);
    return DateTime(first.year, first.month, first.day - (first.weekday % 7));
  }();

  /// Quanti giorni mostra la griglia: **35** (cinque righe) o **42** (sei).
  late final int giorni = () {
    final giorniNelMese = DateTime(mese.year, mese.month + 1, 0).day;
    final prima = DateTime(mese.year, mese.month, 1).weekday % 7;
    return (prima + giorniNelMese) <= 35 ? 35 : 42;
  }();

  int get righe => giorni ~/ colonne;

  /// L'altezza totale: l'intestazione piu' le righe.
  double get altezza => headerHeight + righe * rowHeight;

  /// Il giorno all'indice [indice] (0 = la prima cella, in alto a sinistra).
  DateTime giornoA(int indice) =>
      DateTime(primo.year, primo.month, primo.day + indice);

  /// L'indice della cella di [day], o `-1` se quel giorno non e' nella griglia.
  ///
  /// Il conto si fa in **UTC**: con l'ora legale una giornata dura 23 o 25 ore e
  /// `difference().inDays` sbaglierebbe di uno (stessa regola di `DayAxis`).
  int indiceDi(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    final p = DateTime.utc(primo.year, primo.month, primo.day);
    final n = d.difference(p).inDays;
    return (n < 0 || n >= giorni) ? -1 : n;
  }

  /// Il rettangolo della cella [indice], con l'origine in alto a sinistra della
  /// griglia.
  Rect cellaDi(int indice) => Rect.fromLTWH(
        (indice % colonne) * cellWidth,
        headerHeight + (indice ~/ colonne) * rowHeight,
        cellWidth,
        rowHeight,
      );

  /// Il giorno che sta sotto un punto **locale della griglia** (origine in alto
  /// a sinistra), o `null` se il punto cade nell'intestazione o fuori.
  DateTime? giornoSotto(Offset punto) {
    if (punto.dy < headerHeight) return null;
    final colonna = (punto.dx / cellWidth).floor();
    final riga = ((punto.dy - headerHeight) / rowHeight).floor();
    if (colonna < 0 || colonna >= colonne) return null;
    if (riga < 0 || riga >= righe) return null;
    return giornoA(riga * colonne + colonna);
  }
}
