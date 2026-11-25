import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/calendar/month_grid_geometry.dart';
import 'package:planner/ui/mobile/month_grid.dart';
import 'package:planner/ui/mobile/month_grid_painter.dart';

/// Il calendario del mese: **la griglia di un mese preciso**.
///
/// Il mese è un parametro perché la `PageView` tiene costruite anche le pagine
/// vicine (per non pagarle al primo scorrimento): cercare «una» griglia ne
/// troverebbe tre.
Finder grigliaDelMese(DateTime mese) => find.byWidgetPredicate(
      (w) =>
          w is MonthGrid &&
          w.month.year == mese.year &&
          w.month.month == mese.month,
      skipOffstage: false,
    );

/// Il **disegno** della griglia di [mese]: e' li' che vivono la tinta del giorno
/// sotto il dito (`premuto`) e il cerchio del giorno scelto (`evidenza`).
GrigliaDelMese disegnoDellaGriglia(WidgetTester tester, DateTime mese) {
  final trova = find.descendant(
    of: grigliaDelMese(mese),
    matching: find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is GrigliaDelMese,
    ),
  );
  return tester.widget<CustomPaint>(trova).painter! as GrigliaDelMese;
}

/// Il rettangolo della cella di [giorno] **sullo schermo**.
///
/// Con [nelMese] si guarda la griglia di quel mese: serve ai giorni che si
/// vedono come «fuori mese» (il 2 ottobre nella griglia di settembre).
Rect cellaDelGiorno(
  WidgetTester tester,
  DateTime giorno, {
  DateTime? nelMese,
}) {
  final mese = nelMese ?? giorno;
  final trova = grigliaDelMese(mese);
  final rettangolo = tester.getRect(trova);
  final griglia = tester.widget<MonthGrid>(trova);
  final geometria = MonthGridGeometry(
    month: griglia.month,
    cellWidth: rettangolo.width / MonthGridGeometry.colonne,
    rowHeight: griglia.rowHeight,
    headerHeight: griglia.headerHeight,
  );
  final indice = geometria.indiceDi(giorno);
  if (indice < 0) {
    throw StateError('il giorno $giorno non e\' nella griglia di $mese');
  }
  return geometria.cellaDi(indice).shift(rettangolo.topLeft);
}

/// Tocca un giorno **dove sta il dito**, non dove sta un testo.
///
/// I numeri dei giorni non sono più widget — li disegna il painter — quindi
/// `find.text('16')` non li trova più. Il punto si calcola con la stessa
/// geometria che usa la griglia per capire dove sta il dito: se la geometria
/// sbaglia, sbaglia anche il test (ed è esattamente il legame che si vuole
/// verificare).
Future<void> toccaGiorno(
  WidgetTester tester,
  DateTime giorno, {
  DateTime? nelMese,
}) async =>
    tester.tapAt(cellaDelGiorno(tester, giorno, nelMese: nelMese).center);

/// Tocco **prolungato** su un giorno: la scorciatoia che apre quel giorno.
Future<void> tieniPremutoIlGiorno(
  WidgetTester tester,
  DateTime giorno, {
  DateTime? nelMese,
}) async =>
    tester.longPressAt(cellaDelGiorno(tester, giorno, nelMese: nelMese).center);
