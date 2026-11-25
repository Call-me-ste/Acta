import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/categories/category_controller.dart';
import '../../features/categories/domain/category.dart';
import '../shared/empty_state.dart';
import 'category_chips.dart';
import 'category_editor.dart';

/// "Categorie >": la libreria delle etichette.
///
/// E' una pagina a se' perche' le etichette si **gestiscono** una volta ogni
/// tanto e si **scelgono** spesso: tenerle in fondo alle impostazioni era un
/// passo in piu' per la cosa che si fa di continuo.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryController>().all;

    return Scaffold(
      appBar: AppBar(title: const Text('Categorie')),
      body: categories.isEmpty
          ? const EmptyState(
              icon: Icons.label_outline,
              message: 'Nessuna categoria.\n'
                  'Creane una per ritrovare gli elementi a colpo d\'occhio.',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: categories.length,
              itemBuilder: (context, index) =>
                  _CategoryTile(category: categories[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Categoria'),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final ItemCategory category;

  Future<void> _elimina(BuildContext context, int quanti) async {
    final controller = context.read<CategoryController>();
    final conferma = await showActaDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Eliminare "${category.name}"?'),
        // Il conto degli elementi che la usano: "la usano 12 elementi" e' una
        // decisione diversa da "non la usa nessuno".
        content: Text(
          quanti == 0
              ? 'Non la usa nessun elemento.'
              : quanti == 1
                  ? 'La usa 1 elemento: resta, senza questa etichetta.'
                  : 'La usano $quanti elementi: restano, senza questa etichetta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    await controller.remove(category.id);
  }

  @override
  Widget build(BuildContext context) {
    final quanti = context.watch<CategoryController>().usageCount(category.id);

    return ListTile(
      key: ValueKey('categoria-riga-${category.id}'),
      // Il pallino porta emoji e colore; il nome sta nel titolo, una volta sola.
      leading: CategoryDot(category: category),
      title: Text(category.name),
      subtitle: Text(quanti == 0 ? 'Nessun elemento' : '$quanti elementi'),
      trailing: PopupMenuButton<String>(
        popUpAnimationStyle: menuMotion(context),
        onSelected: (value) {
          if (value == 'edit') showCategoryEditor(context, category: category);
          if (value == 'delete') _elimina(context, quanti);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Modifica')),
          PopupMenuItem(value: 'delete', child: Text('Elimina')),
        ],
      ),
      onTap: () => showCategoryEditor(context, category: category),
    );
  }
}
