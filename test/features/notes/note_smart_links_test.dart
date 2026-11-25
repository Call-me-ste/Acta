import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/notes/note_smart_links.dart';

void main() {
  test('riconosce URL, telefono e data numerica', () {
    final links = estraiSmartLinks(
      'Riunione il 14/10 alle 9, link https://example.com/piano '
      'e telefono +39 333 123 4567',
    );

    expect(
        links.map((l) => l.kind),
        containsAll([
          SmartLinkKind.url,
          SmartLinkKind.phone,
          SmartLinkKind.date,
        ]));
    final data = links.firstWhere((l) => l.kind == SmartLinkKind.date).date;
    expect(data, isNotNull);
    expect(data!.month, 10);
    expect(data.day, 14);
  });

  test('riconosce il mese scritto in italiano', () {
    final links = estraiSmartLinks('Dentista 3 marzo 2027');
    final data = links.single.date;
    expect(data, isNotNull);
    expect(data!.year, 2027);
    expect(data.month, 3);
    expect(data.day, 3);
  });

  test('una data impossibile non viene proposta', () {
    final links = estraiSmartLinks('31/02 non esiste');
    expect(links.where((l) => l.kind == SmartLinkKind.date), isEmpty);
  });

  test('non duplica lo stesso link e ignora i numeri corti', () {
    final links = estraiSmartLinks(
      'https://example.com https://example.com 12345',
    );
    expect(links.where((l) => l.kind == SmartLinkKind.url), hasLength(1));
    expect(links.where((l) => l.kind == SmartLinkKind.phone), isEmpty);
  });
}
