import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/settings/priority_colors.dart';
import 'package:planner/ui/mobile/priority_page.dart';
import 'package:planner/ui/shared/color_name.dart';
import 'package:planner/ui/shared/priority_style.dart';

/// La pagina "Priorita'": i quattro colori si vedono, si cambiano e si riportano
/// a quelli di base.
void main() {
  late DatabaseService db;
  late AppSettingsController settings;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    settings = AppSettingsController(db.settings)..load();
  });

  tearDown(() => db.close());

  Future<void> apri(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettingsController>.value(
        value: settings,
        child: const MaterialApp(home: PriorityPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra i quattro livelli con i colori di base', (tester) async {
    await apri(tester);

    for (final livello in [0, 1, 2, 3]) {
      expect(find.text(priorityLabel(livello)), findsOneWidget);
      // Il nome del colore, non il codice: "Rosso", non #F44336.
      expect(
        find.text(colorNameOfHex(defaultPriorityColors[livello])),
        findsOneWidget,
      );
    }

    // Nessun codice esadecimale in giro: e' la richiesta dell'utente, e una
    // regressione qui si vede subito.
    expect(find.textContaining('#'), findsNothing);

    // Nessun colore cambiato: il ripristino e' spento, cosi' non si tocca per
    // sbaglio un tasto che non cambierebbe niente.
    final bottone = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Ripristina i colori di base'),
        matching: find.byType(TextButton),
      ),
    );
    expect(bottone.onPressed, isNull);
  });

  testWidgets('cambiare un colore lo salva e accende il ripristino',
      (tester) async {
    await apri(tester);

    await tester.tap(find.byKey(const ValueKey('priorita-3')));
    await tester.pumpAndSettle();
    // Il campo del codice non c'e' piu' (passo 12): si sceglie dai colori pronti
    // del selettore (o dalla ruota).
    await tester.tap(find.byKey(const ValueKey('pronto-#81c784')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usa questo'));
    await tester.pumpAndSettle();

    // Il colore e' cambiato **solo** per l'urgente, ed e' scritto in preferenze.
    expect(settings.priorityColorOf(3), '#81c784');
    expect(settings.priorityColorOf(2), defaultPriorityColors[2]);
    // E il nome del colore si legge nella riga.
    expect(colorNameOfHex('#81c784'), 'Verde');
    expect(find.text('Verde'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('ripristina-priorita')));
    await tester.pumpAndSettle();
    expect(settings.priorityColors, defaultPriorityColors);
  });

  testWidgets('annullare non cambia niente', (tester) async {
    await apri(tester);

    await tester.tap(find.byKey(const ValueKey('priorita-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pronto-#9e9e9e')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(settings.priorityColors, defaultPriorityColors);
  });
}
