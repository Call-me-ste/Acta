import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/categories/category_controller.dart';
import '../../features/categories/domain/category.dart';
import '../../features/categories/emoji_suggestions.dart';
import '../../theme/design_tokens.dart';
import '../shared/color_field.dart';
import '../shared/color_name.dart';

/// L'editor di una categoria: nome, emoji, colore.
///
/// Torna la categoria salvata, o `null` se si annulla. Sta in un dialogo e non
/// in una pagina perche' sono tre campi: una pagina intera per tre campi e' un
/// viaggio per andare di la'.
Future<ItemCategory?> showCategoryEditor(
  BuildContext context, {
  ItemCategory? category,
}) {
  return showActaDialog<ItemCategory>(
    context: context,
    builder: (_) => _CategoryEditorDialog(category: category),
  );
}

/// Il contenuto del dialogo, con uno stato suo.
///
/// Il campo di testo ha bisogno di un `TextEditingController` che viva quanto
/// il dialogo: chiuderlo appena `showDialog` torna indietro lo fa morire mentre
/// l'animazione di uscita sta ancora disegnando, e Flutter lo segnala
/// (trovato dal test che apre e salva una categoria).
class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({this.category});

  final ItemCategory? category;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _nome;
  late String _emoji;
  late String _colore;
  String? _errore;

  /// Vero mentre la scrittura e' in corso: con un tocco in piu' su Salva non si
  /// crea una seconda categoria, che era il modo piu' facile di ritrovarsene
  /// due identiche senza accorgersene.
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nome = TextEditingController(text: category?.name ?? '');
    _emoji = category?.emoji ?? '';
    _colore = category?.colorHex ?? '';
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<ItemCategory?> _salva() async {
    final testo = _nome.text.trim();
    if (testo.isEmpty) {
      setState(() => _errore = 'Serve un nome');
      return null;
    }

    final controller = context.read<CategoryController>();
    final category = widget.category;

    // Stesso nome (senza badare a maiuscole e spazi) **e** stessa emoji di una
    // categoria che c'e' gia': non si crea un doppione, e lo si dice invece di
    // aggiungere una riga in silenzio. Con un'emoji diversa, invece, sono due
    // categorie diverse ed e' voluto.
    final doppione = controller.duplicateOf(
      testo,
      _emoji,
      exceptId: category?.id,
    );
    if (doppione != null) {
      setState(
          () => _errore = 'Esiste già «${doppione.name}» con questa emoji');
      return null;
    }

    if (category == null) {
      return controller.create(name: testo, emoji: _emoji, colorHex: _colore);
    }

    final next = category.copyWith(
      name: testo,
      emoji: _emoji,
      colorHex: _colore,
    );
    if (!await controller.save(next)) {
      setState(() => _errore = 'Esiste già una categoria con questo nome');
      return null;
    }
    // Riletta dal controller: porta il clock avanzato, cosi' chi la usa subito
    // non riscrive una versione vecchia.
    return controller.byId(category.id) ?? next;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usate = {
      for (final categoria in context.read<CategoryController>().all)
        if (categoria.emoji.isNotEmpty) categoria.emoji,
    };
    final suggerite = _nome.text.trim().isEmpty
        ? const <String>[]
        : emojiSuggerite(_nome.text, recenti: usate);
    final restanti = [
      for (final scelta in emojiChoices)
        if (!suggerite.contains(scelta)) scelta,
    ];

    return AlertDialog(
      title: Text(
          widget.category == null ? 'Nuova categoria' : 'Modifica categoria'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('nome-categoria'),
              controller: _nome,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Nome',
                errorText: _errore,
                // Due righe: "Esiste già «Lavoro» con questa emoji" su una riga
                // sola si tagliava a meta' parola.
                errorMaxLines: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text('Emoji (facoltativa)', style: theme.textTheme.labelMedium),
            if (suggerite.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Suggerite', style: theme.textTheme.labelSmall),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final scelta in suggerite)
                    _EmojiChip(
                      emoji: scelta,
                      selected: _emoji == scelta,
                      onSelected: (scelto) =>
                          setState(() => _emoji = scelto ? scelta : ''),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final scelta in restanti)
                  _EmojiChip(
                    emoji: scelta,
                    selected: _emoji == scelta,
                    onSelected: (scelto) =>
                        setState(() => _emoji = scelto ? scelta : ''),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('colore-categoria'),
                  onPressed: () async {
                    final scelto = await showColorDialog(
                      context,
                      initialHex: _colore.isEmpty ? '#3F51B5' : _colore,
                      title: 'Colore della categoria',
                    );
                    if (scelto != null) setState(() => _colore = scelto);
                  },
                  icon: const Icon(Icons.palette_outlined),
                  label: Text(
                    _colore.isEmpty
                        ? 'Colore (facoltativo)'
                        : colorNameOfHex(_colore),
                  ),
                ),
                if (_colore.isNotEmpty)
                  IconButton(
                    tooltip: 'Togli il colore',
                    onPressed: () => setState(() => _colore = ''),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const ValueKey('salva-categoria'),
          // La guardia sta **dentro** la callback e non solo nel `onPressed`:
          // due tocchi nello stesso fotogramma arrivano entrambi al widget
          // vecchio, che il controllo "disattivato" non l'ha ancora visto.
          onPressed: () async {
            if (_salvando) return;
            setState(() => _salvando = true);
            final salvata = await _salva();
            if (!mounted) return;
            setState(() => _salvando = false);
            if (salvata == null || !context.mounted) return;
            Navigator.pop(context, salvata);
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

/// Una scelta emoji: stessa forma per suggerite e catalogo, così non ci sono
/// due modi di selezionare la stessa cosa.
class _EmojiChip extends StatelessWidget {
  const _EmojiChip({
    required this.emoji,
    required this.selected,
    required this.onSelected,
  });

  final String emoji;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(emoji),
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
    );
  }
}
