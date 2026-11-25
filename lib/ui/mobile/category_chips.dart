import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/categories/category_controller.dart';
import '../../features/categories/domain/category.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';

/// Le categorie di un elemento, come pastiglie colorate con l'emoji.
///
/// Riceve gli **id** e non le categorie gia' risolte: un id puo' non esistere
/// piu' (categoria cancellata su un altro dispositivo) e chi disegna non deve
/// occuparsene.
class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key, required this.ids, this.dense = false});

  final List<String> ids;

  /// Piu' piccole: per le righe delle liste, dove il titolo conta di piu'.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryController>().byIds(ids);
    if (categories.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final category in categories)
          CategoryChip(category: category, dense: dense),
      ],
    );
  }
}

/// Il pallino di una categoria: cerchio col colore scelto e dentro l'emoji (o
/// l'iniziale del nome, se emoji non c'e').
///
/// Serve dove il nome della categoria e' **gia' scritto accanto**: elenchi e
/// fogli di scelta. Li' la pastiglia col nome lo faceva leggere due volte nella
/// stessa riga - "Lavoro" e "Lavoro" -, che sembra una categoria doppia.
class CategoryDot extends StatelessWidget {
  const CategoryDot({super.key, required this.category, this.size = 32});

  final ItemCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ColorResolver.hexToColor(category.colorHex) ??
        theme.colorScheme.secondaryContainer;
    final dentro = category.emoji.isNotEmpty
        ? category.emoji
        : (category.name.isEmpty
            ? '?'
            : category.name.substring(0, 1).toUpperCase());

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        dentro,
        style: TextStyle(
          fontSize: size * 0.5,
          color: ColorResolver.onColor(color),
        ),
      ),
    );
  }
}

/// Una pastiglia sola: la usano l'elenco, il form e (piu' avanti) le viste.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    this.dense = false,
    this.onDeleted,
  });

  final ItemCategory category;
  final bool dense;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Il colore scelto tinge la pastiglia; senza colore resta del tema, cosi'
    // una categoria senza colore non e' un buco bianco.
    final color = ColorResolver.hexToColor(category.colorHex) ??
        theme.colorScheme.secondaryContainer;
    final scritte = ColorResolver.onColor(color);
    final label = [
      if (category.emoji.isNotEmpty) category.emoji,
      category.name,
    ].join(' ');

    final text =
        (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
            ?.copyWith(color: scritte);

    if (onDeleted != null) {
      return InputChip(
        key: ValueKey('categoria-${category.id}'),
        label: Text(label, style: text),
        backgroundColor: color,
        side: BorderSide.none,
        visualDensity: dense ? VisualDensity.compact : null,
        onDeleted: onDeleted,
        deleteIconColor: scritte,
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      );
    }

    return Container(
      key: ValueKey('categoria-${category.id}'),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: dense ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.pillRadius(dense ? 18 : 24),
      ),
      child: Text(label, style: text),
    );
  }
}
