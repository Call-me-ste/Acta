import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/places/domain/place_suggestions.dart';

/// I suggerimenti della posizione: tetto, ordine, accenti ignorati, refusi.
///
/// Si prova con le stringhe, senza database e senza schermo: la regola è tutta
/// qui, e il form (dopo) non deve poterla aggiustare per conto suo.
void main() {
  const usati = [
    'Piazza Dante',
    'Piazza del Popolo',
    'Esselunga di via Roma',
    'Perù',
    'Dentista',
  ];

  group('ordine dei suggerimenti', () {
    test('chi inizia viene prima di chi contiene', () {
      final trovati = PlaceSuggestions.forQuery('piazza', usati);
      expect(trovati.first, 'Piazza Dante');
      expect(trovati, contains('Piazza del Popolo'));
    });

    test('chi contiene viene prima di chi assomiglia', () {
      final trovati = PlaceSuggestions.forQuery('roma', usati);
      expect(trovati, ['Esselunga di via Roma']);
    });

    test('un refuso trova comunque il posto: «Piazza Dan» -> Piazza Dante', () {
      final trovati = PlaceSuggestions.forQuery('Piazza Dan', usati);
      expect(trovati, contains('Piazza Dante'));
    });

    test('assomiglia anche con le lettere saltate: «pzadan»', () {
      expect(PlaceSuggestions.forQuery('pzadan', usati), ['Piazza Dante']);
    });
  });

  group('accenti e maiuscole', () {
    test('«peru» trova «Perù»', () {
      expect(PlaceSuggestions.forQuery('peru', usati), contains('Perù'));
    });

    test('«PERÙ» e «peru» sono lo stesso posto', () {
      expect(PlaceSuggestions.isKnown('PERU', usati), isTrue);
      expect(PlaceSuggestions.isKnown('perù', usati), isTrue);
    });
  });

  group('tetto e doppioni', () {
    test('mai piu\' di quattro suggerimenti', () {
      final molti = [for (var i = 0; i < 20; i++) 'Piazza numero $i'];
      expect(PlaceSuggestions.forQuery('piazza', molti), hasLength(4));
      expect(PlaceSuggestions.forQuery('piazza', molti, max: 2), hasLength(2));
    });

    test('lo stesso posto scritto in due modi compare una volta sola', () {
      final trovati = PlaceSuggestions.forQuery(
        'piazza',
        ['Piazza Dante', 'piazza dante', 'PIAZZA DANTE'],
      );
      expect(trovati, ['Piazza Dante']);
    });

    test('senza niente scritto non si suggerisce niente', () {
      expect(PlaceSuggestions.forQuery('', usati), isEmpty);
      expect(PlaceSuggestions.forQuery('   ', usati), isEmpty);
    });

    test('chi non c\'entra non compare', () {
      // «benzina» non ha nessuna lettera in comune nell'ordine giusto: con la
      // regola dei refusi anche le lettere saltate contano, quindi la prova usa
      // una parola che davvero non c'entra (non «pizza», che è una sottosequenza
      // di «piazza»).
      expect(PlaceSuggestions.forQuery('benzina', usati), isEmpty);
    });
  });

  group('«Crea …»', () {
    test('un posto nuovo lo propone', () {
      expect(PlaceSuggestions.offersCreate('Palestra', usati), isTrue);
    });

    test('un posto che conosciamo no: quello si sceglie', () {
      expect(PlaceSuggestions.offersCreate('piazza dante', usati), isFalse);
      expect(PlaceSuggestions.offersCreate('  Piazza Dante ', usati), isFalse);
    });

    test('a campo vuoto non si propone niente', () {
      expect(PlaceSuggestions.offersCreate('', usati), isFalse);
    });
  });
}
