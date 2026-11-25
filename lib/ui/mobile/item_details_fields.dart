import 'package:flutter/material.dart';

import '../../features/places/domain/place_suggestions.dart';
import '../../theme/design_tokens.dart';
import '../shared/deferred_build.dart';
import '../shared/form_section_title.dart';
import '../shared/picker_tile.dart';
import 'item_reminder_sheet.dart';

/// I dettagli dell'elemento: **promemoria**, **posizione** e **note**.
///
/// Stanno in un widget solo perché nel form sono una sezione sola, e perché
/// condividono la stessa scelta: quello che si scrive qui non cambia fra evento e
/// todo.
///
/// **Promemoria.** Tre stati che sono quelli della colonna, non tre modi di dire
/// la stessa cosa: «Default» = `null` (si usa l'anticipo delle impostazioni),
/// «Nessuno» = elenco vuoto (questo elemento non avvisa), «Su misura» = uno o più
/// anticipi. Il suono dell'elemento si regola nello stesso foglio.
/// Lo stesso vale per il suono (`null` = eredita).
///
/// **Posizione.** Testo libero con i suggerimenti dei posti già usati: si scrive
/// «Ess» e compare «Esselunga di via Roma». Tetto e ordine stanno in
/// `PlaceSuggestions` (logica pura, con i suoi test); qui c'è solo il disegno, e
/// le pastiglie si vedono **solo mentre si scrive**, così non coprono il form.
class ItemDetailsFields extends StatefulWidget {
  const ItemDetailsFields({
    super.key,
    required this.leads,
    required this.sound,
    required this.onLeads,
    required this.onSound,
    required this.place,
    required this.note,
    required this.usedPlaces,
    required this.onPlace,
    required this.onNote,
    required this.defaultLeadMinutes,
    required this.defaultSound,
    this.fixedReminderTime,
  });

  /// `null` = default delle impostazioni, elenco vuoto = nessuno, altrimenti i
  /// minuti di anticipo (uno o più).
  final List<int>? leads;

  /// `null` = eredita l'impostazione del suono.
  final bool? sound;

  final ValueChanged<List<int>?> onLeads;
  final ValueChanged<bool?> onSound;

  final String place;
  final String note;

  /// I posti già usati, letti dal database **una volta** all'apertura del form.
  final List<String> usedPlaces;

  final ValueChanged<String> onPlace;
  final ValueChanged<String> onNote;

  /// Il default delle impostazioni per questo tipo di elemento, mostrato nella
  /// riga e nel foglio invece della parola «predefinito» da sola.
  final int defaultLeadMinutes;
  final String defaultSound;
  final String? fixedReminderTime;

  @override
  State<ItemDetailsFields> createState() => _ItemDetailsFieldsState();
}

class _ItemDetailsFieldsState extends State<ItemDetailsFields> {
  late final TextEditingController _place =
      TextEditingController(text: widget.place);
  late final TextEditingController _note =
      TextEditingController(text: widget.note);

  @override
  void dispose() {
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  void _use(String place) {
    _place.text = place;
    widget.onPlace(place);
    // I suggerimenti seguono il testo: scelto il posto, spariscono.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Il posto scritto **per intero** non è un suggerimento: proponre «Piazza
    // Dante» a chi ha appena scritto «Piazza Dante» è rumore. Filtrando l'esatto,
    // le pastiglie spariscono quando il campo è completo.
    final suggerimenti = PlaceSuggestions.forQuery(
            _place.text, widget.usedPlaces)
        .where(
            (place) => normalizedPlace(place) != normalizedPlace(_place.text))
        .toList();

    // Questa sezione sta **sotto la piega** del foglio: si costruisce un
    // fotogramma dopo, cosi' l'apertura del form resta leggera (i promemoria, il
    // luogo e le note non li vede nessuno durante l'animazione). Misurato: era il
    // costo che si sentiva toccando una card.
    return DeferredBuild(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerTile(
            icon: Icons.notifications_outlined,
            label: 'Promemoria',
            value: widget.leads?.isEmpty != true &&
                    widget.fixedReminderTime != null
                ? widget.fixedReminderTime!
                : reminderSummary(widget.leads, widget.defaultLeadMinutes),
            onTap: () async {
              final scelta = await scegliPromemoria(
                context,
                leads: widget.leads,
                defaultMinutes: widget.defaultLeadMinutes,
                sound: widget.sound,
                defaultSound: widget.defaultSound,
                fixedReminderTime: widget.fixedReminderTime,
              );
              if (scelta == null || !mounted) return;
              widget.onLeads(scelta.leads);
              widget.onSound(scelta.sound);
            },
          ),
          const FormSectionTitle('Luogo e note', separated: true),
          TextField(
            controller: _place,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Posizione',
              filled: false,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.s),
            ),
            onChanged: (value) {
              widget.onPlace(value);
              setState(() {});
            },
          ),
          if (suggerimenti.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.xs,
              children: [
                for (final place in suggerimenti)
                  ActionChip(
                    label: Text(place),
                    onPressed: () => _use(place),
                  ),
              ],
            ),
          ],
          const Divider(height: AppSpacing.l),
          TextField(
            controller: _note,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note',
              filled: false,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.s),
            ),
            onChanged: widget.onNote,
          ),
        ],
      ),
    );
  }
}
