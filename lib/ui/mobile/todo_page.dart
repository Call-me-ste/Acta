import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/categories/category_controller.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/todo_entry.dart';
import '../../features/todos/todo_filter_controller.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/todos/todo_selection.dart';
import '../../theme/design_tokens.dart';
import '../shared/due_date_label.dart';
import '../shared/empty_state.dart';
import 'item_sheet.dart';
import 'row_collapse.dart';
import 'todo_selection_bar.dart';
import 'todo_header.dart';
import 'todo_rows.dart';

/// La scheda Todo: un'intestazione che dice dove sei e l'elenco con gli scaduti
/// sopra e i completati sotto. La creazione passa dal pulsante Nuovo.
class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  /// Le due fasce: aperte o chiuse. Lo stato sta **qui** e non nella fascia (e'
  /// la lista a decidere quali righe mettere: renderle tutte costa 23 ms). Gli
  /// scaduti partono **chiusi** (richiesta, ogni vista): si aprono al tocco.
  bool _scadutiAperti = false;
  bool _completatiAperti = false;

  /// Quale fascia si sta **chiudendo**: le sue prime righe restano in scena il
  /// tempo dell'animazione, poi spariscono. Senza, la chiusura sarebbe un salto.
  String? _chiudo;

  /// La lista dei figli dell'elenco, tenuta in memoria fra una ricostruzione e
  /// l'altra, con la chiave dei dati che l'hanno prodotta.
  ///
  /// Perche': quando entra una rotta (un foglio o una pagina) Flutter
  /// ricostruisce la pagina **sotto**, e con l'agenda di prova rifare tutte le
  /// righe costava 10-32 ms di build (misurato). Riusando le **stesse istanze**
  /// Flutter salta quei sottoalberi (`updateChild` esce subito se il figlio e'
  /// identico): la ricostruzione torna a costare quasi niente.
  ///
  /// La chiave comprende tutto quello che le righe leggono davvero: i dati (id,
  /// versione, fatto), i filtri, le fasce aperte, il giorno, e le cose che danno
  /// i colori (palette, priorita', categorie). Senza quelle, cambiare palette
  /// lascerebbe le righe vecchie.
  List<RigaElenco>? _righe;
  String _chiave = '';

  /// Quanti completati si mostrano: gli ultimi. La storia intera non serve a
  /// decidere cosa fare adesso.
  static const int _maxCompletati = 10;

  /// Apre o chiude una fascia. Chiudendola le prime righe si animano e **dopo** la
  /// lista si aggiorna senza di loro; le altre spariscono subito (non si vedono, e
  /// costruirle tutte per animarle era il costo da 23 ms che questa pagina evita).
  void _apriChiudi(String fascia, bool aperta) {
    setState(() {
      if (fascia == 'scaduti') {
        _scadutiAperti = aperta;
      } else {
        _completatiAperti = aperta;
      }
      _chiudo = aperta ? null : fascia;
    });
    if (aperta) return;

    Future<void>.delayed(
      // Un margine **proporzionale**, non un `+ 20 ms` scritto a mano: le durate
      // vengono dai token, e `architecture_test` lo pretende (giustamente).
      RigaCheSiChiude.durata * 1.1,
      () {
        if (mounted && _chiudo == fascia) setState(() => _chiudo = null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Intestazione vuota: il nome della sezione e' gia' nella barra di
      // navigazione in basso.
      appBar: AppBar(toolbarHeight: 0, elevation: 0),
      body: Consumer2<TodoProvider, TodoFilterController>(
        builder: (context, provider, filterController, _) {
          final filter = filterController.filter;
          final oggi = DateTime.now();

          // Cosa legge una riga per disegnarsi: se cambia, la memoria va buttata.
          final settings = context.watch<AppSettingsController>();
          final categorie = context.watch<CategoryController>().all;

          final voci = [
            for (final todo in provider.todos) TodoEntry.of(todo, provider),
          ];
          final daFare = [
            for (final voce in voci)
              if (!voce.done) voce
          ];
          final fatte = [
            for (final voce in voci)
              if (voce.done) voce
          ];

          // Gli scaduti stanno in una fascia sola, in cima, da qualunque vista:
          // e' la cosa che non si deve perdere.
          final scaduti = [
            for (final voce in daFare)
              if (voce.due != null && isOverdue(voce.due!, from: oggi)) voce,
          ];
          // Nell'elenco resta quello che la vista chiede, senza gli scaduti (che
          // hanno la fascia sopra) e senza i completati (che l'hanno sotto).
          final visibili = [
            for (final voce in daFare)
              if (!(voce.due != null && isOverdue(voce.due!, from: oggi)) &&
                  filter.matches(voce.todo, done: false, today: oggi))
                voce,
          ];
          // I completati non dipendono dalla vista (riguarda cosa resta da
          // fare), solo dai filtri fini. Si mostrano in piccolo: gli ultimi,
          // non la storia.
          final completati = [
            for (final voce in fatte)
              if (filter.passesCategoriesAndPriorities(voce.todo)) voce,
          ].take(_maxCompletati).toList();

          final nienteDaMostrare =
              visibili.isEmpty && scaduti.isEmpty && completati.isEmpty;

          final chiave = [
            filter.range.name,
            (filter.categoryIds.toList()..sort()).join(','),
            (filter.priorities.toList()..sort()).join(','),
            '$_scadutiAperti/$_completatiAperti',
            '$_chiudo',
            settings.activePaletteId,
            Theme.of(context).brightness.name,
            settings.priorityColors.join(','),
            [
              for (final categoria in categorie)
                '${categoria.id}:${categoria.version}',
            ].join(','),
            '${oggi.year}-${oggi.month}-${oggi.day}',
            for (final voce in voci)
              '${voce.todo.id}:${voce.todo.version}:${voce.done}',
          ].join('|');

          if (_righe == null || _chiave != chiave) {
            _chiave = chiave;
            _righe = _vociDellElenco(scaduti, visibili, completati);
          }

          // Chi e' selezionato: cambia la barra e basta — le righe hanno il loro
          // `Selector`, quindi qui non si ricostruiscono tutte a ogni tocco.
          final selezione = context.watch<SelezioneDeiTodo>();

          return Column(
            children: [
              const SizedBox(height: AppSpacing.s),
              // Con la selezione aperta la barra contestuale prende il posto
              // dell'aggiunta rapida e dell'intestazione: adesso si sta scegliendo,
              // non scrivendo.
              if (selezione.attiva)
                TodoSelectionBar(
                  visibili: [
                    for (final voce in [...scaduti, ...visibili, ...completati])
                      voce.todo.id,
                  ],
                )
              else ...[
                TodoHeader(count: visibili.length),
              ],
              Expanded(
                // Lo stato vuoto sta **qui** e non dentro la lista: prende
                // l'altezza che trova, e dentro una lista (altezza sciolta)
                // chiederebbe un'altezza infinita. E' la seconda volta che ci
                // inciampo: la lista non e' il posto di una cosa che vuole
                // riempire lo spazio.
                child: nienteDaMostrare
                    ? EmptyState(
                        icon: Icons.checklist_outlined,
                        message: voci.isEmpty
                            ? 'Nessun To do'
                            : 'Nessun To do in questa vista',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        itemCount: _righe!.length,
                        itemBuilder: (context, indice) =>
                            costruisciRiga(context, _righe![indice]),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuovo To do',
        onPressed: () => showItemForm(
          context,
          type: ItemType.todo,
          day: DateTime.now(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Le righe **descritte**: intestazioni e todo. I widget si costruiscono nel
  /// `ListView.builder`, solo quando entrano nello schermo.
  List<RigaElenco> _vociDellElenco(
    List<TodoEntry> scaduti,
    List<TodoEntry> visibili,
    List<TodoEntry> completati,
  ) {
    return [
      if (scaduti.isNotEmpty)
        RigaIntestazione(
          titolo: 'Scaduti',
          icona: Icons.warning_amber,
          count: scaduti.length,
          open: _scadutiAperti,
          onToggle: () => _apriChiudi('scaduti', !_scadutiAperti),
          errore: true,
        ),
      // In chiusura le prime righe restano per l'animazione; le altre spariscono
      // subito, senza essere costruite.
      for (final (indice, voce) in scaduti.indexed)
        if (_scadutiAperti)
          RigaTodo(voce)
        else if (_chiudo == 'scaduti' && indice < RigaCheSiChiude.quante)
          RigaTodo(voce, chiusura: true),
      for (final voce in visibili) RigaTodo(voce),
      if (completati.isNotEmpty)
        RigaIntestazione(
          titolo: 'Completati',
          icona: Icons.check_circle_outline,
          count: completati.length,
          open: _completatiAperti,
          onToggle: () => _apriChiudi('completati', !_completatiAperti),
        ),
      for (final (indice, voce) in completati.indexed)
        if (_completatiAperti)
          RigaTodo(voce)
        else if (_chiudo == 'completati' && indice < RigaCheSiChiude.quante)
          RigaTodo(voce, chiusura: true),
      const RigaSpazio(),
    ];
  }
}
