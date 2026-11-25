import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/categories/domain/category.dart';
import 'package:planner/ui/mobile/item_form_color.dart';

void main() {
  const categoria = ItemCategory(
    id: 'c1',
    name: 'Lavoro',
    colorHex: '#E53935',
  );

  test('evento: il colore della categoria diventa hex libero', () {
    final colore = coloreDellaCategoria(
      evento: true,
      categorie: const [categoria],
    );

    expect(colore, isNotNull);
    expect(colore!.hex, '#E53935');
    expect(colore.index, isNull);
  });

  test('todo: il colore della categoria diventa indice standard', () {
    final colore = coloreDellaCategoria(
      evento: false,
      categorie: const [categoria],
    );

    expect(colore!.index, 0);
    expect(colore.hex, isNull);
  });

  test('una categoria senza colore non tocca il default', () {
    final colore = coloreDellaCategoria(
      evento: true,
      categorie: const [ItemCategory(id: 'c2', name: 'Senza')],
    );

    expect(colore, isNull);
  });
}
