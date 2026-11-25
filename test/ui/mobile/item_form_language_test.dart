import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/item_form.dart';
import 'package:planner/ui/mobile/item_type.dart';
import 'package:planner/ui/mobile/item_title_field.dart';
import 'package:planner/ui/shared/form_sheet.dart';
import 'package:planner/theme/design_tokens.dart';

import '../../support/theme_providers.dart';

/// Il form dice **cosa succede**, non il nome del meccanismo: niente più «Come
/// impostazioni» per promemoria e suono, e ogni riga porta il valore vero.
void main() {
  late DatabaseService db;
  late EventProvider events;
  late TodoProvider todos;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
    todos = TodoProvider(db);
  });

  tearDown(() => db.close());

  Future<void> pumpForm(WidgetTester tester, ItemType type) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ...themeProviders(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ItemForm(type: type, day: DateTime(2026, 9, 14)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> apri(WidgetTester tester, String riga) async {
    await tester.ensureVisible(find.text(riga));
    await tester.pumpAndSettle();
    await tester.tap(find.text(riga));
    await tester.pumpAndSettle();
  }

  testWidgets('niente «Come impostazioni»: le righe dicono il valore',
      (tester) async {
    await pumpForm(tester, ItemType.evento);

    expect(find.text('Come impostazioni'), findsNothing);
    expect(find.text('15 min prima'), findsOneWidget);
    expect(find.text('Suono'), findsNothing);
    // Ripetizione e avvisi sono una sezione sola, con righe della stessa
    // altezza: niente note che allungano solo il promemoria.
    expect(find.text('Ripetizione e avvisi'), findsOneWidget);
    expect(find.text('Predefinito delle impostazioni'), findsNothing);
    expect(find.text('Non si ripete'), findsOneWidget);
  });

  testWidgets('i selettori non riaprono la tastiera del titolo',
      (tester) async {
    await pumpForm(tester, ItemType.evento);
    final campo = find.widgetWithText(TextField, 'Titolo');
    final editor =
        find.descendant(of: campo, matching: find.byType(EditableText));

    for (final riga in ['Giorno', 'Inizio', 'Ripetizione', 'Promemoria']) {
      await tester.ensureVisible(campo);
      await tester.showKeyboard(campo);
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isTrue);

      await apri(tester, riga);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isFalse,
          reason: riga);
      expect(tester.testTextInput.isVisible, isFalse, reason: riga);
    }
  });

  testWidgets('il titolo prende il focus dopo l’apertura del foglio',
      (tester) async {
    final title = TextEditingController();
    addTearDown(title.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFormSheet(
              context,
              (_) => ItemTitleField(controller: title, autofocus: true),
              durataApertura: AppMotion.normal,
            ),
            child: const Text('Apri'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Apri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('il promemoria multiplo si legge come una frase', (tester) async {
    await pumpForm(tester, ItemType.evento);
    await apri(tester, 'Promemoria');

    expect(find.text('Predefinito'), findsOneWidget);
    expect(find.text('Nessun promemoria'), findsOneWidget);
    expect(find.text('Minuti personalizzati…'), findsNothing);
    await tester.tap(find.text('Personalizza'));
    await tester.pumpAndSettle();
    expect(find.text('Minuti personalizzati…'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('anticipo-15')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('anticipo-30')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Fatto'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Fatto'));
    await tester.pumpAndSettle();

    expect(find.text('15 min e 30 min prima'), findsOneWidget);
  });

  testWidgets('il suono si sceglie per nome', (tester) async {
    await pumpForm(tester, ItemType.evento);
    await apri(tester, 'Promemoria');
    await tester.tap(find.text('Suono'));
    await tester.pumpAndSettle();

    expect(find.text('Predefinito'), findsWidgets);
    expect(find.text('Sistema'), findsWidgets);
    expect(find.text('Suona'), findsOneWidget);

    await tester.tap(find.text('Silenzioso'));
    await tester.pumpAndSettle();

    expect(find.text('Silenzioso'), findsOneWidget);
  });

  testWidgets('la priorità è una riga con il suo foglio', (tester) async {
    await pumpForm(tester, ItemType.todo);

    expect(find.text('Bassa'), findsOneWidget);
    await apri(tester, 'Priorità');
    await tester.tap(find.text('Urgente'));
    await tester.pumpAndSettle();

    expect(find.text('Urgente'), findsOneWidget);
  });
}
