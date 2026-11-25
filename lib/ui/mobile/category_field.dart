import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../core/categories/category_ids.dart';
import '../../features/categories/category_controller.dart';
import '../../theme/design_tokens.dart';
import '../shared/empty_state.dart';
import '../shared/form_section_title.dart';
import '../shared/top_inset.dart';
import 'category_editor.dart';
import 'category_chips.dart';

/// Il selettore delle categorie: quelle scelte, piu' il tasto per aggiungerne.
///
/// Il tetto di [maxCategoriesPerItem] sta nel codec degli id, non qui: qui si
/// spiega e si disattiva il tasto, la' si impedisce. Cosi' il limite vale anche
/// per un record che arriva da un altro dispositivo.
class CategoryField extends StatelessWidget {
  const CategoryField({super.key, required this.ids, required this.onChanged});

  final List<String> ids;
  final ValueChanged<List<String>> onChanged;

  /// La voce del foglio che apre l'editor invece di scegliere.
  static const String _nuova = '__nuova__';

  Future<void> _scegli(BuildContext context) async {
    // Il foglio non puo' arrivare nella zona delle notifiche: lo spazio della
    // barra di stato si legge **qui**, perche' dentro un foglio vale zero.
    final sopra = topInset(context);

    final scegli = await showActaSheet<String>(
      context: context,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - sopra,
      ),
      builder: (_) => _CategorySheet(selected: ids),
    );
    if (scegli == null || !context.mounted) return;

    if (scegli == _nuova) {
      final creata = await showCategoryEditor(context);
      if (creata != null) onChanged([...ids, creata.id]);
      return;
    }

    if (ids.contains(scegli)) {
      onChanged(ids.where((id) => id != scegli).toList());
    } else if (ids.length < maxCategoriesPerItem) {
      onChanged([...ids, scegli]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryController>().byIds(ids);
    final pieno = ids.length >= maxCategoriesPerItem;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionTitle('Categorie', separated: true),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final category in categories)
              CategoryChip(
                category: category,
                onDeleted: () => onChanged(
                  ids.where((id) => id != category.id).toList(),
                ),
              ),
            OutlinedButton.icon(
              key: const ValueKey('aggiungi-categoria'),
              onPressed: pieno ? null : () => _scegli(context),
              icon: const Icon(Icons.add, size: AppSpacing.icon),
              label: Text(pieno ? 'Tre: il massimo' : 'Aggiungi'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.touchTarget),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// L'elenco da cui scegliere: nome, emoji e colore di ogni categoria.
///
/// Torna l'id scelto (per toglierlo o metterlo), o [_nuova] se si vuole crearne
/// una sul momento, o `null` se si chiude il foglio.
class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.selected});

  final List<String> selected;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CategoryController>();
    final categories = controller.all;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: Row(
              children: [
                Text(
                  'Categorie',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${selected.length} di $maxCategoriesPerItem',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: EmptyState(
                icon: Icons.label_outline,
                message: 'Nessuna categoria: crea la prima',
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final scelta = selected.contains(category.id);
                  return ListTile(
                    key: ValueKey('scegli-${category.id}'),
                    // Pallino e non pastiglia: il nome e' gia' nel titolo, la
                    // pastiglia lo ripeterebbe nella stessa riga.
                    leading: CategoryDot(category: category),
                    title: Text(category.name),
                    trailing: scelta
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, category.id),
                  );
                },
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Nuova categoria'),
            onTap: () => Navigator.pop(context, CategoryField._nuova),
          ),
        ],
      ),
    );
  }
}
