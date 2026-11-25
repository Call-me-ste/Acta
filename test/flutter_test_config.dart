import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// Bootstrap di **tutta** la suite di test.
///
/// `CalendarPage` mostra i giorni e i mesi in italiano: `table_calendar` li
/// formatta con intl, che pretende i dati di locale caricati prima del primo
/// build. L'app lo fa in `main()`; qui vale per ogni test, così nessuno deve
/// ricordarsene (i test che montavano la pagina da soli fallivano con
/// `LocaleDataException: Locale data has not been initialized`).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting('it_IT');
  await testMain();
}
