import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/events/event_provider.dart';
import '../../features/filters/filtro_condiviso.dart';
import '../../features/palette/palette_controller.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/todo_provider.dart';
import '../../theme/color_resolver.dart';
import 'month_cache.dart';
import 'month_cells_cache.dart';
import 'month_grid_painter.dart';
import 'month_grid_cells.dart';
import 'month_window_cache.dart';

/// La coda del **precaricamento** dei mesi vicini: un mese per fotogramma.
///
/// Perché serve: la griglia di un mese chiede due finestre (eventi e todo, ~4 ms
/// con l'agenda di prova). Chiedendole dentro il fotogramma dello scorrimento,
/// quel fotogramma le paga tutte insieme; chiedendole prima, in un fotogramma in
/// cui non si muove niente, il mese è già pronto quando arriva.
///
/// **Uno per fotogramma**: due finestre insieme sono ~8 ms, cioè un fotogramma
/// saltato. Il primo mese vicino è quello che si guarda per primo scorrendo
/// **avanti** (il verso più frequente), poi quello indietro.
///
/// Sta in un file suo perché è una coda con la sua memoria, e la vista dei mesi
/// ha già la sua (le tre viste, il mese guardato, la griglia).
class PrecaricoDeiMesi {
  PrecaricoDeiMesi({required this.scalda});

  /// Chiede ai provider la finestra di un mese: la stessa chiamata che fa la
  /// griglia, così si scalda una cache che qualcuno legge davvero.
  final void Function(DateTime mese) scalda;

  /// I mesi già chiesti (`anno * 12 + mese`): non si richiedono.
  final Set<int> _scaldati = {};

  /// La coda: un mese per fotogramma.
  final List<DateTime> _coda = [];

  /// Accoda i mesi vicini a [focusedDay] (una volta sola per mese) e fa partire
  /// la coda.
  ///
  /// Due per lato, come le pagine che il pager tiene pronte: il primo è quello
  /// che si guarda per primo scorrendo **avanti** (il verso più frequente), poi
  /// quello indietro; il terzo e il quarto sono i due che servono a uno
  /// scorrimento doppio nello stesso verso.
  void programma(DateTime focusedDay) {
    final centro = DateTime(focusedDay.year, focusedDay.month);
    for (final scarto in [1, -1, 2, -2]) {
      final mese = DateTime(centro.year, centro.month + scarto);
      if (_scaldati.add(mese.year * 12 + mese.month)) _coda.add(mese);
    }
    _prossimo();
  }

  void _prossimo() {
    if (_coda.isEmpty) return;
    final mese = _coda.removeAt(0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scalda(mese);
      _prossimo();
    });
  }
}

/// Scalda **un mese che non si sta guardando**: la finestra (dati) e le **celle**
/// (i testi misurati).
///
/// Le celle servono quanto i dati, e forse più: la pagina che entra dal bordo
/// nasce **nuova** (gli elementi seguono il mese), e nel suo primo disegno
/// preparerebbe 42 testi — nel fotogramma in cui il dito è ancora giù. Profilato:
/// era `prima=nulla` su tutte e cinque le pagine, ~19 ms.
void scaldaIlMese(
  BuildContext context, {
  required DateTime mese,
  required DateTime selezione,
  required FinestreDeiMesi finestre,
  required CachePerMese<List<GiornoPronto>> celle,
  required FiltroCondiviso filtro,
}) {
  final eventi = context.read<EventProvider>();
  final todo = context.read<TodoProvider>();

  final theme = Theme.of(context);
  final stili = StiliDelMese.di(theme, theme.colorScheme);
  // Con la modalita' «nascosta» il precaricamento prepara celle **senza pallini**:
  // prepararle con i pallini sarebbe lavoro per un disegno che non si fa, e la
  // firma diversa farebbe ricalcolare tutto al primo cambio di modalita'.
  final conTodo = context.read<AppSettingsController>().todoInCalendario !=
      TodoInCalendario.nascosta;
  final palette = context
      .read<PaletteController>()
      .resolve(context.read<AppSettingsController>().activePaletteId);
  final finestra = finestre.di(
    mese: mese,
    eventi: eventi,
    todo: todo,
    selezione: selezione,
    filtro: filtro,
  );

  scaldaLeCelle(
    celle: celle,
    mese: mese,
    conTodo: conTodo,
    selezione: selezione,
    // La stessa firma che calcola la griglia quando disegna, filtro compreso:
    // altrimenti il precarico scalderebbe celle che la griglia non legge.
    filtro: filtro.firma,
    // Oggi si legge adesso: la firma delle celle guarda solo il **mese** di
    // questa data, e la vista passa `DateTime.now()` alla griglia a ogni disegno.
    oggi: DateTime.now(),
    generazione: (eventi.generazione, todo.generazione),
    eventsByDay: finestra.eventsByDay,
    todoCounts: finestra.todoCounts,
    stili: stili,
    scheme: theme.colorScheme,
    larghezzaNumero: MisureMese.di(
      context,
      cellWidth: MediaQuery.sizeOf(context).width / 7,
    ).latoNumero,
    // I colori si **leggono**, non si ascoltano: questo gira in un callback di
    // fine fotogramma, e li' `watch` (che e' quello che usa `occurrenceColor`) e'
    // un'asserzione di provider. La palette si risolve una volta per mese.
    coloreEvento: (evento) => ColorResolver.elementColor(
      palette: palette,
      brightness: theme.brightness,
      index: evento.colorIndex,
      customHex: evento.event.colorHex,
    ),
  );
}
