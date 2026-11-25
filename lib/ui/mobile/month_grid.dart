import 'package:flutter/material.dart';

import '../../features/calendar/month_grid_geometry.dart';
import '../../features/events/domain/event_occurrence.dart';
import '../../theme/design_tokens.dart';
import '../shared/date_math.dart';
import '../shared/event_colors.dart';
import 'month_cache.dart';
import 'month_cells_cache.dart';
import 'month_grid_cells.dart';
import 'month_grid_painter.dart';
import 'month_grid_touch.dart';

/// La griglia del mese: **una pagina, un disegno, un gesto**.
///
/// Tre cose che prima erano di `table_calendar` e ora sono nostre, perché sono
/// esattamente i tre costi misurati sul telefono:
///
/// * il **disegno**: un `CustomPaint` invece di 42 celle da una ventina di widget
///   l'una (~290 µs a cella, 13-16 ms dei 25-36 del fotogramma di cambio mese);
/// * il **gesto**: un solo strato che copre la griglia e traduce il punto in un
///   giorno (`MonthGridGeometry.giornoSotto`). Non si perde più il tocco subito
///   dopo uno scorrimento: prima il riconoscitore viveva dentro la cella, e la
///   cella veniva ricostruita proprio mentre il dito era giù;
/// * le **misure dei testi**: una volta per disegno (vedi `month_grid_cells.dart`),
///   non a ogni fotogramma.
///
/// L'aspetto non cambia: le posizioni sono quelle di prima al pixel (i golden lo
/// verificano) e il pieno del giorno scelto si accende e si spegne con la stessa
/// durata di prima — un controller per **pagina**, non uno per cella.
class MonthGrid extends StatefulWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.eventsByDay,
    required this.todoCounts,
    required this.conTodo,
    required this.filtroFirma,
    required this.generazione,
    required this.celle,
    required this.animate,
    required this.rowHeight,
    required this.headerHeight,
    required this.onDaySelected,
    required this.onOpenDay,
  });

  /// Un giorno qualunque del mese da disegnare.
  final DateTime month;

  /// Il giorno scelto: il suo cerchio si accende.
  final DateTime selectedDay;

  /// Oggi: numero colorato e in grassetto, senza cerchio (se non è scelto).
  final DateTime today;

  /// Gli eventi del mese, per giorno (`MonthWindow.eventsByDay`).
  final Map<DateTime, List<EventOccurrence>> eventsByDay;

  /// Quanti todo non fatti cadono in ogni giorno (`MonthWindow.todoCounts`).
  final Map<DateTime, int> todoCounts;

  /// Se i todo si vedono nel calendario: con la modalita' «nascosta» i pallini
  /// non si disegnano. Entra nella **firma** delle celle, perche' altrimenti
  /// quelle gia' in memoria continuerebbero a mostrarli; con i conteggi vuoti il
  /// disegno non cambia da solo, quindi la decisione sta in un posto solo.
  final bool conTodo;

  /// La memoria delle celle, per mese: sta nella vista (una per calendario) e non
  /// in una variabile globale, altrimenti sopravviverebbe ai test e a un secondo
  /// calendario.
  final CachePerMese<List<GiornoPronto>> celle;

  /// La **firma del filtro** condiviso: barre e pallini delle celle sono copiati
  /// dai dati gia' filtrati, quindi entra nella firma delle celle come la
  /// modalita' «todo nel calendario». Senza, togliere un filtro lascerebbe in
  /// memoria le celle di prima.
  final String filtroFirma;

  /// Quante volte i dati sono cambiati (i due provider): e' la firma che dice se
  /// le celle preparate valgono ancora.
  ///
  /// Serve cosi': lo scorrimento fra i mesi ricostruisce questa griglia a ogni
  /// evento del dito (le pagine si spostano per **layout**, non con un
  /// `Transform`: con la trasformazione il tocco durante l'assestamento non
  /// arrivava piu'). Senza firma, ogni fotogramma riallineava anche i 42 testi —
  /// misurato sul telefono: **20-23 ms di build per fotogramma**. Con la firma,
  /// se i dati non sono cambiati i paragrafi restano quelli di prima.
  final (int, int) generazione;

  /// Animazioni accese (preferenza dell'app o «riduci animazioni» di sistema).
  final bool animate;

  /// Altezza di una riga e della fascia dei nomi: le decide la vista, che sa
  /// quanto è grande il testo.
  final double rowHeight;
  final double headerHeight;

  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onOpenDay;

  @override
  State<MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<MonthGrid>
    with SingleTickerProviderStateMixin {
  /// L'evidenza del giorno scelto, da 0 a 1: si accende sul nuovo e si spegne sul
  /// vecchio, invece di saltare.
  late final AnimationController _evidenza = AnimationController(
    vsync: this,
    value: 1,
  );

  /// Il giorno scelto **prima**: è quello che si spegne.
  DateTime? _primaSelezione;

  /// L'ultimo disegno preparato. Serve a rifare **solo** le due celle che si
  /// accendono o si spengono a ogni fotogramma, senza rimisurare le altre
  /// quaranta (misurare un paragrafo costa, e sono 42).
  ///
  /// Vengono dalla memoria per mese (`CachePerMese`): questa pagina può anche
  /// nascere adesso, ma le sue celle possono essere già pronte.
  List<GiornoPronto> _ferme = const [];

  /// La scatola del numero per questa pagina: cambia con la scala del testo.
  double _larghezzaNumero = latoNumeroBase;

  /// I nomi dei giorni, misurati una volta per stile.
  List<TextPainter>? _nomi;
  TextStyle? _stileNomi;

  @override
  void didUpdateWidget(MonthGrid vecchio) {
    super.didUpdateWidget(vecchio);
    if (dateOnly(vecchio.selectedDay) == dateOnly(widget.selectedDay)) return;

    _primaSelezione = dateOnly(vecchio.selectedDay);
    _evidenza.duration = widget.animate ? AppMotion.normal : Duration.zero;
    _evidenza.forward(from: 0);
  }

  @override
  void dispose() {
    _evidenza.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stili = StiliDelMese.di(Theme.of(context), scheme);

    return LayoutBuilder(
      builder: (context, vincoli) {
        final misure = MisureMese.di(
          context,
          cellWidth: vincoli.maxWidth / MonthGridGeometry.colonne,
        );
        _larghezzaNumero = misure.latoNumero;
        final geometria = MonthGridGeometry(
          month: widget.month,
          cellWidth: vincoli.maxWidth / MonthGridGeometry.colonne,
          rowHeight: widget.rowHeight,
          headerHeight: widget.headerHeight,
        );

        if (_nomi == null || _stileNomi != stili.nomi) {
          _nomi = nomiDeiGiorni(geometria, stili.nomi);
          _stileNomi = stili.nomi;
        }

        // Le celle si preparano **una volta per disegno**, non a ogni fotogramma
        // dell'animazione, e **non** quando non e' cambiato niente: lo
        // scorrimento fra i mesi ricostruisce questa griglia a ogni evento del
        // dito, e riallineare 42 paragrafi ogni volta costava 20-23 ms di build.
        //
        // E le celle stanno **fuori** da questa pagina (`CachePerMese`): la pagina
        // che entra dal bordo nasce nuova, e senza memoria preparerebbe 42 testi
        // nel fotogramma in cui il dito e' ancora giu'. Le prepara prima il
        // precaricamento, in un fotogramma inattivo.
        _ferme = widget.celle.di(
          mese: widget.month,
          firma: firmaDelleCelle(
            mese: widget.month,
            generazione: widget.generazione,
            selezione: widget.selectedDay,
            oggi: widget.today,
            stili: stili,
            conTodo: widget.conTodo,
            filtro: widget.filtroFirma,
            larghezzaNumero: misure.latoNumero,
          ),
          prepara: () => preparaLeCelle(
            mese: widget.month,
            selezione: widget.selectedDay,
            oggi: widget.today,
            eventsByDay: widget.eventsByDay,
            todoCounts: widget.conTodo ? widget.todoCounts : const {},
            stili: stili,
            scheme: scheme,
            coloreEvento: (evento) => occurrenceColor(context, evento),
            larghezzaNumero: misure.latoNumero,
          ),
        );

        return ToccoDelMese(
          geometria: geometria,
          onDaySelected: widget.onDaySelected,
          onOpenDay: widget.onOpenDay,
          child: (context, premuto) => AnimatedBuilder(
            animation: _evidenza,
            builder: (context, _) => CustomPaint(
              size: Size(vincoli.maxWidth, geometria.altezza),
              painter: GrigliaDelMese(
                geometria: geometria,
                giorni: _conEvidenza(geometria, stili, scheme, _evidenza.value),
                nomi: _nomi!,
                coloreCerchio: scheme.primary,
                coloreBadge: scheme.tertiary,
                latoNumero: misure.latoNumero,
                premuto: premuto,
                coloreTinta: scheme.onSurface.withValues(alpha: 0.12),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Prepara un giorno della griglia: il mese, la selezione e i dati li mette
  /// questo metodo (sono lo stato della griglia), tutto il resto lo fa
  /// `preparaGiorno` — che sta con le altre misure, in `month_grid_cells.dart`.
  GiornoPronto _prepara(
    int indice,
    DateTime giorno,
    StiliDelMese stili,
    ColorScheme scheme, {
    double? evidenza,
  }) =>
      preparaGiorno(
        indice: indice,
        giorno: giorno,
        mese: widget.month,
        selezione: widget.selectedDay,
        oggi: widget.today,
        stili: stili,
        scheme: scheme,
        eventsByDay: widget.eventsByDay,
        todoCounts: widget.todoCounts,
        coloreEvento: (evento) => occurrenceColor(context, evento),
        larghezzaNumero: _larghezzaNumero,
        evidenza: evidenza,
      );

  /// Le celle pronte per il fotogramma che si sta disegnando: ferme, tranne le
  /// due che si stanno accendendo o spegnendo.
  List<GiornoPronto> _conEvidenza(
    MonthGridGeometry geometria,
    StiliDelMese stili,
    ColorScheme scheme,
    double valore,
  ) {
    final precedente = _primaSelezione;
    if (precedente == null || valore >= 1) return _ferme;

    // Due indici, non quarantadue confronti di date: la cella il suo indice ce
    // l'ha gia', e `indiceDi` fa il conto in **UTC** — con l'ora legale una
    // giornata dura 23 o 25 ore, e `difference().inDays` sbaglierebbe di uno.
    final accesa = geometria.indiceDi(widget.selectedDay);
    final spenta = geometria.indiceDi(precedente);
    return [
      for (final fermo in _ferme)
        if (fermo.indice == accesa)
          _prepara(fermo.indice, geometria.giornoA(fermo.indice), stili, scheme,
              evidenza: valore)
        else if (fermo.indice == spenta)
          _prepara(fermo.indice, geometria.giornoA(fermo.indice), stili, scheme,
              evidenza: 1 - valore)
        else
          fermo,
    ];
  }
}
