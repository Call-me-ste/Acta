import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/ui/shared/tab_active.dart';

/// Il meccanismo che tiene un widget fuori dalle notifiche quando la sua scheda
/// non si guarda — e lo riporta dentro appena torna in scena.
///
/// Si conta in **ricostruzioni**, non in millisecondi: un tempo preso in debug
/// non vale niente, una ricostruzione mancata e' un fatto. Il valore mostrato
/// dice l'altra meta' della garanzia: quando la scheda torna, i dati sono quelli
/// di adesso.
///
/// Nessun provider qui dentro: `ChangeNotifierProvider` aggiunge un ascolto suo,
/// quindi `hasListeners` sarebbe vero comunque e la prova non direbbe niente.
void main() {
  late _Contatore contatore;

  setUp(() => contatore = _Contatore());

  Future<void> mostra(WidgetTester tester, bool attivo) => tester.pumpWidget(
        MaterialApp(
          home: _Sonda(contatore: contatore, attivo: attivo),
        ),
      );

  testWidgets('con la scheda nascosta una notifica non ricostruisce il widget',
      (tester) async {
    await mostra(tester, false);
    final costruzioni = contatore.costruzioni;
    expect(find.text('valore 0'), findsOneWidget);
    expect(contatore.ascoltato, isFalse, reason: 'non si iscrive affatto');

    contatore.avanti();
    await tester.pump();

    expect(
      contatore.costruzioni,
      costruzioni,
      reason: 'il widget non e\' iscritto: la scrittura non lo tocca',
    );
    expect(
      find.text('valore 0'),
      findsOneWidget,
      reason: 'e non si aggiorna da solo mentre nessuno lo guarda',
    );
  });

  testWidgets('con la scheda attiva la stessa notifica lo ricostruisce',
      (tester) async {
    await mostra(tester, true);
    final costruzioni = contatore.costruzioni;

    contatore.avanti();
    await tester.pump();

    expect(contatore.costruzioni, costruzioni + 1);
    expect(find.text('valore 1'), findsOneWidget);
  });

  testWidgets(
      'la scheda che si **lascia** smette di ascoltare davvero: non basta '
      'smettere di chiedere i dati', (tester) async {
    // E' il caso che ha bocciato la prima versione di questo meccanismo: una
    // dipendenza da un `InheritedWidget` non si disdice, quindi un widget che
    // aveva fatto `watch` restava iscritto anche passando a `read`. Misurato:
    // la griglia del mese nascosta si ricostruiva lo stesso.
    await mostra(tester, true);
    contatore.avanti();
    await tester.pump();
    expect(find.text('valore 1'), findsOneWidget);

    await mostra(tester, false);
    final costruzioni = contatore.costruzioni;
    expect(contatore.ascoltato, isFalse, reason: 'l\'ascolto si toglie');

    contatore.avanti();
    await tester.pump();

    expect(contatore.costruzioni, costruzioni);
    expect(find.text('valore 1'), findsOneWidget);
  });

  testWidgets(
      'tornando attiva si allinea ai dati di adesso, non a quelli di '
      'quando e\' stata lasciata', (tester) async {
    await mostra(tester, false);
    contatore.avanti();
    contatore.avanti();
    await tester.pump();
    expect(find.text('valore 0'), findsOneWidget);

    await mostra(tester, true);
    await tester.pump();

    expect(find.text('valore 2'), findsOneWidget);
  });

  testWidgets('quando il widget se ne va, l\'ascolto se ne va con lui',
      (tester) async {
    await mostra(tester, true);
    expect(contatore.ascoltato, isTrue);

    await tester.pumpWidget(const SizedBox());

    expect(contatore.ascoltato, isFalse, reason: 'niente ascolti appesi');
  });

  testWidgets('senza un TabActive sopra ci si comporta come sempre: attivo',
      (tester) async {
    // E' il caso dei test e dei widget aperti a parte: se il default fosse
    // «nascosto», una pagina fuori dal guscio resterebbe ferma.
    await tester.pumpWidget(
      MaterialApp(
        home: AscoltatoriSeAttivo(
          notifiers: [contatore],
          builder: (context) {
            contatore.costruzioni++;
            return Text('valore ${contatore.valore}');
          },
        ),
      ),
    );

    contatore.avanti();
    await tester.pump();
    expect(find.text('valore 1'), findsOneWidget);
  });
}

class _Contatore extends ChangeNotifier {
  int valore = 0;

  /// Quante volte il widget che osserva si e' costruito.
  int costruzioni = 0;

  bool get ascoltato => hasListeners;

  void avanti() {
    valore++;
    notifyListeners();
  }
}

class _Sonda extends StatelessWidget {
  const _Sonda({required this.contatore, required this.attivo});

  final _Contatore contatore;
  final bool attivo;

  @override
  Widget build(BuildContext context) {
    return TabActive(
      attivo: attivo,
      child: AscoltatoriSeAttivo(
        notifiers: [contatore],
        // Si legge, non si ascolta: l'ascolto lo tiene `AscoltatoriSeAttivo`, e
        // averlo in due posti vorrebbe dire non poterlo togliere.
        builder: (context) {
          contatore.costruzioni++;
          return Text('valore ${contatore.valore}');
        },
      ),
    );
  }
}
