import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/theme/design_tokens.dart';
import 'package:planner/ui/shared/view_push_switcher.dart';
import 'package:planner/ui/shared/view_push_switcher_view.dart';

/// Il cambio vista del calendario: le due schede scorrono insieme, ognuna col
/// suo sfondo pieno.
///
/// Le posizioni si leggono dal FractionalTranslation di ogni vista.
void main() {
  Widget harness(int index, {bool animate = true, int pages = 3}) {
    return MaterialApp(
      home: Scaffold(
        body: ViewPushSwitcher(
          index: index,
          animate: animate,
          children: [
            for (var i = 0; i < pages; i++)
              _Contatore(etichetta: String.fromCharCode(65 + i)),
          ],
        ),
      ),
    );
  }

  /// Apre una vista e lascia finire i fotogrammi di avvio: quello che costruisce
  /// le altre viste e quello del riscaldamento (che le dipinge una volta e poi le
  /// rimette a posto). Da lì in poi ogni cambio è un gesto dell'utente.
  Future<void> apri(WidgetTester tester, int indice,
      {bool animate = true}) async {
    await tester.pumpWidget(harness(indice, animate: animate));
    await tester.pumpAndSettle();
  }

  /// Lo scostamento di una scheda, in frazione della sua **larghezza**.
  double dx(WidgetTester tester, int indice) {
    return tester
        .widget<FractionalTranslation>(
          find.descendant(
            of: find.byKey(ValueKey('vista-$indice'), skipOffstage: false),
            matching: find.byType(FractionalTranslation),
          ),
        )
        .translation
        .dx;
  }

  bool fuoriScena(WidgetTester tester, int indice) {
    return tester
        .widget<Offstage>(
          find.descendant(
            of: find.byKey(ValueKey('vista-$indice'), skipOffstage: false),
            matching: find.byType(Offstage),
          ),
        )
        .offstage;
  }

  /// Quello che le schede **in scena** coprono, in frazione della larghezza:
  /// ognuna sta su `[dx, dx+1]` e l'unione deve coprire tutto lo schermo.
  ///
  /// E' il difetto segnalato («ho cliccato settimana ed e' uscita schermata
  /// vuota»): quando la transizione in coda veniva annullata appena armata, le
  /// schede se ne andavano tutte fuori scena e sotto si vedeva lo sfondo. Il
  /// buco e' invisibile a un test che guarda solo `dx` di una scheda: si vede
  /// solo guardando **tutte** le schede insieme.
  String buco(WidgetTester tester, {int pages = 3}) {
    final intervalli = <List<double>>[];
    for (var indice = 0; indice < pages; indice++) {
      if (fuoriScena(tester, indice)) continue;
      final dove = dx(tester, indice);
      intervalli.add([dove, dove + 1]);
    }
    intervalli.sort((a, b) => a[0].compareTo(b[0]));

    var fine = 0.0;
    for (final intervallo in intervalli) {
      if (intervallo[0] > fine + 0.001) {
        return '${fine.toStringAsFixed(3)}..${intervallo[0].toStringAsFixed(3)}';
      }
      if (intervallo[1] > fine) fine = intervallo[1];
    }
    return fine < 1 - 0.001 ? '${fine.toStringAsFixed(3)}..1' : '';
  }

  testWidgets('le altre viste si costruiscono dopo il primo disegno',
      (tester) async {
    await tester.pumpWidget(harness(0));
    expect(find.text('A=0'), findsOneWidget);
    expect(find.text('B=0', skipOffstage: false), findsNothing);

    // Le viste aggiuntive si preparano una per fotogramma.
    await tester.pump();
    expect(find.text('B=0', skipOffstage: false), findsOneWidget);
    expect(find.text('C=0', skipOffstage: false), findsNothing);

    // E il fotogramma dopo tornano fuori scena, al loro posto.
    await tester.pumpAndSettle();
    expect(fuoriScena(tester, 1), isTrue);
    expect(fuoriScena(tester, 2), isTrue);
    expect(fuoriScena(tester, 0), isFalse);
  });

  testWidgets('all\'apertura le viste si disegnano una volta, coperte',
      (tester) async {
    await tester.pumpWidget(harness(0));
    await tester.pump();

    // Fotogramma del riscaldamento: una sola pagina nuova, a posto zero.
    expect(fuoriScena(tester, 1), isFalse);
    expect(find.text('C=0', skipOffstage: false), findsNothing);
    expect(dx(tester, 1), 0.0);
    // E sono **sotto** quella attiva, che è opaca: l'ordine dello Stack decide
    // chi si vede, quindi il riscaldamento non cambia niente a schermo.
    expect(
      tester
          .widgetList<VistaSpostata>(find.byType(VistaSpostata))
          .map((widget) => widget.key)
          .last,
      const ValueKey('vista-0'),
    );

    // A riposo tornano fuori scena, ferme dal lato della gerarchia.
    await tester.pumpAndSettle();
    expect(fuoriScena(tester, 1), isTrue);
    expect(dx(tester, 1), 1.0);
  });

  testWidgets('il primo fotogramma arma le schede, il secondo le muove',
      (tester) async {
    await apri(tester, 0);
    await tester.pumpWidget(harness(1));
    await tester.pump();

    // Armate: l'entrante è ferma nel punto da cui entrerà, l'uscente è a posto.
    // Serve a non far partire l'animazione nel fotogramma in cui la pagina si
    // ricompone (quello è il fotogramma pesante: 9-22 ms misurati sul telefono).
    expect(dx(tester, 1), 1.0);
    expect(dx(tester, 0), 0.0);

    // Il fotogramma dopo partono le destinazioni.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(dx(tester, 1), lessThan(1.0));
    expect(dx(tester, 0), lessThan(0.0));

    // E il movimento è **reattivo ma non istantaneo**: a 250 ms sta ancora
    // correndo (la durata è 320 ms).
    await tester.pump(const Duration(milliseconds: 150));
    expect(dx(tester, 1), greaterThan(0.0));
    await tester.pumpAndSettle();
    expect(dx(tester, 1), 0.0);
  });

  testWidgets('ogni scheda ha lo sfondo pieno: sotto non si vede niente',
      (tester) async {
    await apri(tester, 0);
    await tester.pumpWidget(harness(1));
    await tester.pump(const Duration(milliseconds: 150));

    for (final indice in [0, 1]) {
      final sfondo = tester.widget<Material>(
        find.byKey(ValueKey('scheda-$indice'), skipOffstage: false),
      );
      expect(
        sfondo.color?.a,
        1.0,
        reason: 'la scheda $indice deve essere opaca, non trasparente',
      );
    }
  });

  testWidgets('al primo fotogramma l\'entrante è fuori dal bordo',
      (tester) async {
    await apri(tester, 0);
    await tester.pumpWidget(harness(1));
    await tester.pump();

    expect(dx(tester, 1), 1.0, reason: 'una larghezza intera: non si vede');

    await tester.pumpAndSettle();
    expect(dx(tester, 1), 0.0);
    expect(fuoriScena(tester, 0), isTrue);
    expect(fuoriScena(tester, 1), isFalse);
  });

  testWidgets('le due schede si coprono: nessun buco di sfondo, con parallasse',
      (tester) async {
    await apri(tester, 0);
    await tester.pumpWidget(harness(1));
    await tester.pump();

    // Solo mentre l'animazione corre (300 ms): a movimento finito l'uscente va
    // fuori scena.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final entrante = dx(tester, 1);
      final uscente = dx(tester, 0);

      expect(entrante, lessThan(1.0));
      expect(entrante, greaterThan(0.0));
      expect(uscente, lessThanOrEqualTo(0.0));
      // La scheda che esce si muove di **un quarto** di quella che entra.
      expect(
        uscente,
        closeTo(-ViewPushSwitcher.parallax * (1 - entrante), 0.002),
        reason: 'parallasse: quella che esce scivola dietro',
      );
      // E coprono sempre tutto: il bordo destro di quella che esce sta oltre il
      // bordo sinistro di quella che entra. Nessun buco di sfondo, mai.
      expect(1 + uscente, greaterThanOrEqualTo(entrante));
    }
  });

  testWidgets(
      'anche col fotogramma del cambio pesante, le due schede restano in fase',
      (tester) async {
    await apri(tester, 0);

    // Il fotogramma del cambio **con il tempo che passa davvero**: sul telefono
    // quello è il fotogramma pesante (9-22 ms misurati: ricostruisce la pillola,
    // ricompone le schede, aggiorna le preferenze), e una scheda che parte in
    // anticipo lì dentro si mangia un pezzo di movimento. Nei test `pump()` senza
    // durata non lo mostra: il fotogramma costa zero.
    await tester.pumpWidget(harness(1));
    await tester.pump(const Duration(milliseconds: 20));

    // Da qui in poi i due movimenti devono restare **in fase**: quanto ha già
    // percorso quella che esce deve valere quanto quella che entra.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final entrante = dx(tester, 1);
      final uscente = dx(tester, 0);
      final progressoEntrante = 1 - entrante;
      final progressoUscente = -uscente / ViewPushSwitcher.parallax;

      expect(
        progressoUscente,
        closeTo(progressoEntrante, 0.02),
        reason:
            'la scheda che esce e quella che entra devono muoversi insieme: '
            'se una parte prima, nell\'animazione si vede un salto',
      );
    }
  });

  testWidgets('due richieste ravvicinate: l\'ultima vince subito',
      (tester) async {
    await apri(tester, 0);

    // Prima richiesta: 0 -> 1, e la lascio a metà.
    await tester.pumpWidget(harness(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Seconda richiesta **mentre la prima corre**: l'utente ha già scelto, quindi
    // la vista 2 parte subito e la 1 non viene mostrata fino in fondo.
    await tester.pumpWidget(harness(2));
    await tester.pump();
    await tester.pump(AppMotion.viewRetarget);

    expect(dx(tester, 2), 0.0);
    expect(fuoriScena(tester, 2), isFalse);

    // L'uscente si toglie di scena a fine movimento.
    await tester.pumpAndSettle();
    expect(fuoriScena(tester, 1), isTrue);
    expect(fuoriScena(tester, 0), isTrue);
  });

  testWidgets('ripensamento ravvicinato: si torna subito', (tester) async {
    await apri(tester, 0);

    await tester.pumpWidget(harness(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Ripensamento prima che la scheda 1 sia arrivata: si torna al mese senza
    // aspettare che la settimana finisca il suo movimento.
    await tester.pumpWidget(harness(0));
    await tester.pump();
    await tester.pump(AppMotion.viewRetarget);

    expect(dx(tester, 0), 0.0);
    expect(fuoriScena(tester, 0), isFalse);

    await tester.pumpAndSettle();
    expect(fuoriScena(tester, 1), isTrue);
    expect(tester.binding.transientCallbackCount, 0,
        reason: 'niente animazioni appese');
  });

  testWidgets(
      'due tocchi ravvicinati: nessun fotogramma a schermo vuoto, e la vista '
      'chiesta resta', (tester) async {
    await apri(tester, 0);

    // Primo tocco (settimana), col fotogramma del cambio che costa davvero.
    await tester.pumpWidget(harness(1));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 120));

    // Secondo tocco (giorno) mentre il primo corre: la richiesta si accoda.
    await tester.pumpWidget(harness(2));
    await tester.pump();

    // Da qui in poi le schede devono **sempre** coprire lo schermo. Il fotogramma
    // che rompeva tutto e' quello in cui la prima transizione finisce e la
    // seconda si arma: le due schede della prima finiscono insieme, e il `onEnd`
    // di quella che era appena **entrata** arrivava quando il turno era gia'
    // passato, annullando la transizione in coda appena armata.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(buco(tester), '',
          reason: 'al fotogramma $i nessuna scheda copriva il buco: e\' la '
              '«schermata vuota»');
    }

    await tester.pumpAndSettle();
    expect(dx(tester, 2), 0.0, reason: 'la vista chiesta e\' arrivata');
    expect(fuoriScena(tester, 1), isTrue);
    expect(fuoriScena(tester, 0), isTrue);
    expect(tester.binding.transientCallbackCount, 0,
        reason: 'niente animazioni appese');
  });

  testWidgets('due tocchi: l\'ultima vista vince senza aspettare la prima',
      (tester) async {
    await apri(tester, 0);

    // Primo tocco (settimana), lasciato a metà.
    await tester.pumpWidget(harness(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    // Secondo tocco (giorno) mentre la settimana sta ancora entrando: l'utente
    // ha già scelto, quindi il giorno non deve aspettare i 560 ms della prima.
    await tester.pumpWidget(harness(2));
    await tester.pump();
    await tester.pump(AppMotion.viewRetarget);

    expect(
      dx(tester, 2),
      0.0,
      reason: 'la seconda richiesta deve essere già arrivata, non in coda',
    );
    expect(fuoriScena(tester, 2), isFalse);
    await tester.pumpAndSettle();
    expect(fuoriScena(tester, 1), isTrue);
  });

  testWidgets('venti sequenze rapide: nessun tap perso', (tester) async {
    await apri(tester, 0);

    for (var giro = 0; giro < 20; giro++) {
      await tester.pumpWidget(harness(1));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(harness(2));
      await tester.pump(AppMotion.viewRetarget);
      expect(fuoriScena(tester, 2), isFalse,
          reason: 'giro $giro: il giorno deve essere in scena');

      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(0));
      await tester.pump(AppMotion.viewRetarget);
      expect(fuoriScena(tester, 0), isFalse,
          reason: 'ritorno $giro: il mese deve essere in scena');
      await tester.pumpAndSettle();
    }
  });

  testWidgets('i nuovi tocchi conservano le posizioni e la copertura',
      (tester) async {
    await apri(tester, 0);
    for (final next in [1, 0, 2, 1, 0, 2, 0]) {
      final before = {
        for (var i = 0; i < 3; i++)
          if (!fuoriScena(tester, i)) i: dx(tester, i),
      };
      await tester.pumpWidget(harness(next));
      for (final entry in before.entries) {
        expect(dx(tester, entry.key), closeTo(entry.value, 0.001));
      }
      await tester.pump();
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(buco(tester), isEmpty);
      }
    }
    await tester.pumpAndSettle();
    expect(dx(tester, 0), 0);
    expect(fuoriScena(tester, 1), isTrue);
    expect(fuoriScena(tester, 2), isTrue);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('raffiche su cinque schede mantengono coperto il viewport',
      (tester) async {
    final random = Random(49);
    var active = 0;
    await tester.pumpWidget(harness(active, pages: 5));
    await tester.pumpAndSettle();
    for (var tap = 0; tap < 70; tap++) {
      active = (active + 1 + random.nextInt(4)) % 5;
      await tester.pumpWidget(harness(active, pages: 5));
      for (var frame = 0; frame <= tap % 8; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(buco(tester, pages: 5), isEmpty,
            reason: 'tocco $tap, frame $frame');
      }
    }
    await tester.pumpAndSettle();
    expect(dx(tester, active), 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('niente trasparenza: nessun livello di opacità nel cambio',
      (tester) async {
    await apri(tester, 0);
    await tester.pumpWidget(harness(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    Finder dentroIlCambio(Type tipo) => find.descendant(
          of: find.byType(ViewPushSwitcher),
          matching: find.byType(tipo),
          skipOffstage: false,
        );

    expect(dentroIlCambio(Opacity), findsNothing);
    expect(dentroIlCambio(FadeTransition), findsNothing);
  });

  testWidgets('scendendo si entra da destra, risalendo da sinistra',
      (tester) async {
    await apri(tester, 0);
    await tester.pumpWidget(harness(1));
    await tester.pump();

    // Mese → settimana: la settimana **aspettava a destra**, quindi entra da lì.
    expect(dx(tester, 1), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(dx(tester, 0), lessThan(0), reason: 'e il mese se ne va a sinistra');
    await tester.pumpAndSettle();

    // Risalendo: il mese aspettava a **sinistra**, quindi entra da lì.
    await tester.pumpWidget(harness(0));
    await tester.pump();
    expect(dx(tester, 0), lessThan(0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(dx(tester, 1), greaterThan(0), reason: 'e la settimana va a destra');
    await tester.pumpAndSettle();
    expect(dx(tester, 0), 0.0);
  });

  testWidgets('con le animazioni spente il cambio è istantaneo',
      (tester) async {
    await apri(tester, 0, animate: false);
    await tester.pumpWidget(harness(1, animate: false));
    await tester.pump();

    expect(fuoriScena(tester, 0), isTrue);
    expect(dx(tester, 1), 0.0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('lo stato di una vista sopravvive al giro', (tester) async {
    await apri(tester, 0);
    await tester.tap(find.text('A=0'));
    await tester.pump();
    expect(find.text('A=1'), findsOneWidget);

    await apri(tester, 2);
    await apri(tester, 0);

    // Il contatore è ancora a 1: la vista non è stata distrutta, solo nascosta.
    expect(find.text('A=1'), findsOneWidget);
  });

  testWidgets('la vista che esce non riceve i tocchi', (tester) async {
    await apri(tester, 0);
    await tester.pumpWidget(harness(1));
    await tester.pump();

    final ignorato = tester.widget<IgnorePointer>(
      find.descendant(
        of: find.byKey(const ValueKey('vista-0'), skipOffstage: false),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(ignorato.ignoring, isTrue);
  });
}

/// Una vista con stato: serve a dimostrare che sopravvive al cambio.
class _Contatore extends StatefulWidget {
  const _Contatore({required this.etichetta});

  final String etichetta;

  @override
  State<_Contatore> createState() => _ContatoreState();
}

class _ContatoreState extends State<_Contatore> {
  int _n = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _n++),
        child: Text('${widget.etichetta}=$_n'),
      ),
    );
  }
}
