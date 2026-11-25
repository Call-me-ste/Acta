import '../../features/categories/domain/category.dart';
import '../../theme/event_palette.dart';

/// Il colore della prima categoria con una tinta, adattato al tipo di elemento.
/// Evento: hex libero. Todo: indice nella tavolozza standard (la sua tabella non
/// ha un hex proprio).
({int? index, String? hex})? coloreDellaCategoria({
  required bool evento,
  required Iterable<ItemCategory> categorie,
}) {
  for (final categoria in categorie) {
    if (categoria.colorHex.isEmpty) continue;
    if (evento) return (index: null, hex: categoria.colorHex);
    final index = EventPalette.colors.indexWhere(
      (hex) => hex.toUpperCase() == categoria.colorHex.toUpperCase(),
    );
    if (index >= 0) return (index: index, hex: null);
  }
  return null;
}
