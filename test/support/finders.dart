import 'package:flutter_test/flutter_test.dart';

import 'package:planner/ui/mobile/month_pager.dart';

/// Il calendario, cercato per **sottotipo** e non per tipo esatto.
///
/// `find.byType(...)` matcha il tipo esatto: è bastato cambiare il parametro
/// generico di `TableCalendar` (quando le celle hanno cominciato a ricevere i
/// conteggi di eventi e todo) perché il finder non trovasse più niente, con l'app
/// perfettamente funzionante. Con la griglia nostra la lezione è la stessa: si
/// cerca il **pager dei mesi**, che è uno solo e non dipende dal tipo della
/// pagina.
///
/// Per arrivare alla griglia di un giorno preciso c'è `test/support/grid.dart`:
/// la `PageView` tiene costruite anche le pagine vicine, quindi di griglie ce ne
/// sono tre.
final calendarFinder = find.byWidgetPredicate((w) => w is MonthPager);
