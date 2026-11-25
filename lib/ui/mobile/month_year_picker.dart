import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/design_tokens.dart';
import '../shared/form_sheet.dart';
import 'month_picker_cells.dart';
import 'year_strip.dart';

/// Il primo e l'ultimo anno che si possono scegliere.
///
/// Duecento anni: chi ha una data vecchia, un anniversario o un appuntamento
/// lontano non deve stare dentro una finestra decisa da noi. Il calendario vero ha
/// gli stessi estremi: sceglierne uno fuori sarebbe un tocco che non porta da
/// nessuna parte.
const int primoAnno = 1900;
const int ultimoAnno = 2100;

/// La scelta di anno e mese, fatta come la fanno i calendari veri.
///
/// Cosa dice la ricerca (Samsung Calendar, Apple Calendar, le linee guida
/// Material e quelle di accessibilita'):
/// - **Samsung**: si tocca il titolo e si apre una scelta che porta subito a un
///   mese di un anno lontano; c'e' un comando **Oggi**.
/// - **Apple**: zoom gerarchico — anno, poi mese, poi giorno. Il titolo si tocca,
///   e la scelta resta **in contesto** invece di essere una schermata a parte.
/// - **Linee guida**: la discesa progressiva (mese → anno → mese) e' il modello
///   giusto; da **evitare** la rotella nativa per intervalli ampi (si resta
///   "a meta' fra due anni", ed e' esattamente quello che succedeva).
///
/// Quindi: una **striscia di anni** che si scorre (discreta: si tocca un anno, non
/// si "cade" fra due), i **dodici mesi** sotto in griglia regolare, e due comandi
/// che non obbligano a scegliere il mese:
/// - **Oggi** (Samsung): torna al mese corrente;
/// - **Vai a `mese anno`**: tiene il mese che stavi guardando e cambia solo
///   l'anno — chi voleva solo spostarsi di un anno non deve ri-scegliere il mese.
///
/// Toccare un mese, invece, porta li' e chiude: e' la discesa progressiva.
Future<DateTime?> showMonthYearPicker(
  BuildContext context, {
  required DateTime initial,
}) {
  return showFormSheet<DateTime>(
    context,
    (sheetContext) => MonthYearSheet(initial: initial),
  );
}

/// Il contenuto del foglio (pubblico per i test: cosi' si prova senza aprire il
/// foglio e senza dipendere dalla sua animazione).
class MonthYearSheet extends StatefulWidget {
  const MonthYearSheet({super.key, required this.initial, this.today});

  final DateTime initial;

  /// Il giorno "oggi" per il comando omonimo: nei test si fissa.
  final DateTime? today;

  @override
  State<MonthYearSheet> createState() => _MonthYearSheetState();
}

class _MonthYearSheetState extends State<MonthYearSheet> {
  /// La larghezza di una voce, **che cresce con il testo**: con quattro cifre a
  /// caratteri ingranditi (sul telefono il sistema è a 1,3) la voce fissa da 64
  /// px non bastava e l'anno andava a capo — «199» e poi «9». Una voce larga
  /// quanto serve lo tiene su una riga sola.
  static double _larghezzaVoce(BuildContext context) =>
      72 * MediaQuery.textScalerOf(context).scale(1);

  late int _anno = widget.initial.year;

  /// Il controller della striscia: si usa per **centrare** l'anno in vista
  /// all'apertura (l'offset dipende dalla larghezza della voce, che dipende dalla
  /// scala del testo).
  late final ScrollController _striscia = ScrollController();

  @override
  void initState() {
    super.initState();
    // La striscia nasce **con l'anno in vista al centro**: aprendola non si deve
    // scorrere per ritrovare il punto in cui si era. Si fa dopo il primo
    // fotogramma, quando la larghezza della voce è nota (dipende dalla scala del
    // testo, che prima del disegno non si può sapere).
    WidgetsBinding.instance.addPostFrameCallback((_) => _centra(_anno));
  }

  /// Porta l'anno al centro della striscia: si arrotonda al multiplo della voce,
  /// così la striscia si ferma sempre **su un anno** e mai fra due.
  void _centra(int anno) {
    if (!mounted || !_striscia.hasClients) return;
    final voce = _larghezzaVoce(context);
    final vista = _striscia.position.viewportDimension;
    final grezzo = (anno - primoAnno) * voce - (vista - voce) / 2;
    _striscia.jumpTo(grezzo.clamp(0, _striscia.position.maxScrollExtent));
  }

  DateTime get _oggi => widget.today ?? DateTime.now();

  @override
  void dispose() {
    _striscia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mesi = DateFormat.MMM('it_IT');
    final oggi = _oggi;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Vai a', style: theme.textTheme.titleLarge),
                ),
                // Samsung: il comando che riporta al mese di oggi, sempre a portata.
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    DateTime(oggi.year, oggi.month),
                  ),
                  icon: const Icon(Icons.today, size: 18),
                  label: const Text('Oggi'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),

            // ─── La striscia degli anni (condivisa con il foglio della settimana) ───
            YearStrip(
              anno: _anno,
              annoOggi: oggi.year,
              onAnno: (anno) => setState(() => _anno = anno),
            ),
            const SizedBox(height: AppSpacing.m),

            // ─── I dodici mesi dell'anno scelto ───
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.s,
              crossAxisSpacing: AppSpacing.s,
              childAspectRatio: 1.9,
              children: [
                for (var mese = 1; mese <= 12; mese++)
                  MeseCell(
                    etichetta: _nome(mesi.format(DateTime(_anno, mese))),
                    // Scelto = il mese che stai guardando (se l'anno e' quello).
                    // Oggi = un riferimento leggero, e solo nell'anno corrente.
                    scelto: _anno == widget.initial.year &&
                        mese == widget.initial.month,
                    oggi: _anno == oggi.year && mese == oggi.month,
                    onTap: () =>
                        Navigator.of(context).pop(DateTime(_anno, mese)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              // Per cambiare **solo** l'anno: si tocca lo stesso mese nell'anno
              // nuovo. Non serve un pulsante di conferma, e prima c'era.
              'Tocca un mese per andarci',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _nome(String valore) {
    return toBeginningOfSentenceCase(valore) ?? valore;
  }
}
