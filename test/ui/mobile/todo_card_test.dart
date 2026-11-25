import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/ui/mobile/todo_card.dart';
import 'package:planner/ui/shared/priority_style.dart';
import 'package:planner/ui/shared/todo_check.dart';

/// La scheda del todo: cerchio di spunta, colore scelto, priorita' visibile.
///
/// Sta in piedi da sola (prende un `Todo` e quattro callback): cosi' si prova
/// senza montare la pagina intera, che ha provider, ricorrenze e occorrenze.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Widget harness(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsController>.value(
            value: AppSettingsController(db.settings)..load(),
          ),
          ChangeNotifierProvider<PaletteController>.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: Center(child: child))),
      );

  Todo todo({
    String title = 'Spesa',
    int priority = 0,
    int? colorIndex,
    DateTime? dueDate,
  }) {
    return Todo(
      id: 't1',
      title: title,
      priority: priority,
      colorIndex: colorIndex,
      dueDate: dueDate,
    );
  }

  Future<void> pump(WidgetTester tester, Widget card) async {
    await tester.pumpWidget(harness(card));
    await tester.pumpAndSettle();
  }

  testWidgets('il cerchio si spunta, anima e chiama chi deve salvare',
      (tester) async {
    var tocchi = 0;
    await pump(
      tester,
      TodoCard(
        todo: todo(),
        done: false,
        onToggle: () => tocchi++,
        onTap: () {},
      ),
    );

    expect(find.byType(TodoCheck), findsOneWidget);
    // Da fare: la spunta non c'e' ancora (scala a zero).
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0,
    );

    await tester.tap(find.byType(TodoCheck));
    await tester.pumpAndSettle();
    expect(tocchi, 1);

    // Ora e' fatto: la spunta entra con un'animazione, non di colpo.
    await pump(
      tester,
      TodoCard(
        todo: todo(),
        done: true,
        onToggle: () {},
        onTap: () {},
      ),
    );
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets(
      'la priorita\' si legge dal colore, e il segno c\'e\' quando conta',
      (tester) async {
    final colori = <Color>{};

    for (final livello in [0, 1, 2, 3]) {
      await pump(
        tester,
        TodoCard(
          todo: todo(priority: livello),
          done: false,
          onToggle: () {},
          onTap: () {},
        ),
      );

      // La barretta dice sempre il livello; il **segno** compare solo per Alta e
      // Urgente, le due che contano.
      expect(
        find.byIcon(priorityIcon(livello)),
        livello >= 2 ? findsOneWidget : findsNothing,
      );
      // La parola non sta sulla riga: sta nel form e nei filtri, dove si sceglie.
      expect(find.text(priorityLabel(livello)), findsNothing);

      final contesto = tester.element(find.byType(TodoCard));
      // `listen: false`: si sta leggendo fuori dal build, e `watch` lo
      // segnalerebbe come errore (o meglio: e' proprio il caso che provider
      // vieta).
      final impostazioni =
          Provider.of<AppSettingsController>(contesto, listen: false);
      final contenitore = tester.widget<Container>(
        find.byKey(const ValueKey('barretta-priorita')),
      );
      final bordo = (contenitore.decoration! as BoxDecoration).border!;
      final colore = (bordo as Border).left.color;
      expect(colore, priorityColorFrom(impostazioni.priorityColors, livello));
      colori.add(colore);
    }

    // Quattro livelli, quattro colori diversi.
    expect(colori, hasLength(4));
  });

  testWidgets('lo sfondo è monocolore, il colore vive sul cerchio',
      (tester) async {
    await pump(
      tester,
      TodoCard(todo: todo(), done: false, onToggle: () {}, onTap: () {}),
    );
    final sfondoNeutro = tester
        .widget<Material>(find.byKey(const ValueKey('sfondo-todo')))
        .color;
    final cerchioNeutro =
        tester.widget<TodoCheck>(find.byType(TodoCheck)).color;

    await pump(
      tester,
      TodoCard(
        todo: todo(colorIndex: 2),
        done: false,
        onToggle: () {},
        onTap: () {},
      ),
    );
    final sfondoColorato = tester
        .widget<Material>(find.byKey(const ValueKey('sfondo-todo')))
        .color;
    final cerchioColore =
        tester.widget<TodoCheck>(find.byType(TodoCheck)).color;

    // Sfondo uguale per **tutte** le righe: la tinta al 18% rendeva l'elenco
    // sbiadito (segnalato), e la gerarchia la fanno priorità, data e chip.
    expect(sfondoColorato, sfondoNeutro);

    // Il colore scelto non sparisce: resta sul cerchio, e si vede anche da
    // fermo (l'anello, non la spunta — quella è solo da fatto).
    expect(cerchioColore, isNotNull);
    expect(cerchioColore, isNot(cerchioNeutro));
    final anello = tester
        .widget<AnimatedContainer>(find.byType(AnimatedContainer))
        .decoration! as BoxDecoration;
    expect(
      (anello.border! as Border).top.color,
      cerchioColore,
      reason: "da fermo l'anello porta il colore scelto",
    );
  });

  testWidgets('la scadenza parla: Oggi, Scaduta da N giorni', (tester) async {
    final oggi = DateTime.now();
    await pump(
      tester,
      TodoCard(
        todo: todo(dueDate: oggi),
        done: false,
        onToggle: () {},
        onTap: () {},
      ),
    );
    expect(find.text('Oggi'), findsOneWidget);

    await pump(
      tester,
      TodoCard(
        todo: todo(
          dueDate: DateTime(oggi.year, oggi.month, oggi.day - 3),
        ),
        done: false,
        onToggle: () {},
        onTap: () {},
      ),
    );
    expect(find.text('Scaduta da 3 giorni'), findsOneWidget);
    // Il segno d'avviso: un'icona in piu' del solo colore.
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets('un todo fatto non e\' piu\' in ritardo', (tester) async {
    final oggi = DateTime.now();
    await pump(
      tester,
      TodoCard(
        todo: todo(dueDate: DateTime(oggi.year, oggi.month, oggi.day - 5)),
        done: true,
        onToggle: () {},
        onTap: () {},
      ),
    );

    expect(find.text('Scaduta da 5 giorni'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });
}
