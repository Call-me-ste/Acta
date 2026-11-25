import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/item_form.dart';
import 'package:planner/ui/mobile/item_type.dart';

/// Promemoria, posizione e note nel form: si **salvano davvero** e si
/// **rileggono** dal database, «Nessuno» pulisce, i suggerimenti dei posti non
/// superano il tetto.
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

  Widget harness(ItemForm form) => MultiProvider(
        providers: [
          // Il form legge i posti già usati dal database: senza questo provider
          // i suggerimenti restano vuoti (e i test non proverebbero niente).
          Provider<DatabaseService>.value(value: db),
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ChangeNotifierProvider<AppSettingsController>.value(
            value: AppSettingsController(db.settings)..load(),
          ),
          ChangeNotifierProvider<PaletteController>.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
          ChangeNotifierProvider<CategoryController>.value(
            value: CategoryController(db),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: form)),
      );

  Future<void> apri(WidgetTester tester, ItemForm form) async {
    // Tela alta: il form è lungo e i pulsanti stanno in fondo.
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(harness(form));
    await tester.pumpAndSettle();
  }

  Future<void> salva(WidgetTester tester) async {
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
  }

  testWidgets('posizione, note e promemoria si salvano e si rileggono',
      (tester) async {
    await apri(
      tester,
      ItemForm(type: ItemType.evento, day: DateTime(2026, 9, 14)),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Titolo'),
      'Dentista',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Posizione'),
      'Via Roma 1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Note'),
      'portare la tessera',
    );
    // Promemoria su misura: due anticipi, con il suono spento.
    await tester.tap(find.text('Promemoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personalizza'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('anticipo-15')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('anticipo-60')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('anticipo-60')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Suono'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suono'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Silenzioso'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Fatto'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Fatto'));
    await tester.pumpAndSettle();

    await salva(tester);

    final salvato = db.getEvents().map(Event.fromRow).single;
    expect(salvato.location, 'Via Roma 1');
    expect(salvato.note, 'portare la tessera');
    expect(salvato.reminderLeads, [15, 60]);
    expect(salvato.reminderSound, isFalse);
  });

  testWidgets('«Nessuno» pulisce gli anticipi: vuoto, non «default»',
      (tester) async {
    await events.addEvent(
      title: 'Dentista',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
      reminderLeads: const [60],
      reminderSound: true,
    );

    await apri(
      tester,
      ItemForm(
        type: ItemType.evento,
        day: DateTime(2026, 9, 14),
        event: events.events.single,
      ),
    );

    // In modifica i valori ci sono già: la nota e l'anticipo si vedono.
    expect(find.widgetWithText(TextField, 'Posizione'), findsOneWidget);
    expect(find.text('1 ora prima'), findsOneWidget);

    await tester.tap(find.text('Promemoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nessun promemoria'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Fatto'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Fatto'));
    await tester.pumpAndSettle();
    await salva(tester);

    final salvato = db.getEvents().map(Event.fromRow).single;
    expect(
      salvato.reminderLeads,
      isEmpty,
      reason: 'nessuno, non «usa il default delle impostazioni»',
    );
    expect(salvato.reminderSound, isTrue,
        reason: 'il suono non è stato toccato');
  });

  testWidgets('si può aggiungere un anticipo personalizzato', (tester) async {
    await apri(
      tester,
      ItemForm(type: ItemType.evento, day: DateTime(2026, 9, 14)),
    );

    await tester.tap(find.text('Promemoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personalizza'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Minuti personalizzati…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minuti personalizzati…'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('anticipo-personalizzato')),
      '45',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Aggiungi'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Fatto'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Fatto'));
    await tester.pumpAndSettle();

    expect(find.text('45 min prima'), findsOneWidget);
  });

  testWidgets('Suono si trova nel promemoria', (tester) async {
    await apri(
      tester,
      ItemForm(type: ItemType.evento, day: DateTime(2026, 9, 14)),
    );

    expect(find.text('Suono'), findsNothing);
    await tester.tap(find.text('Promemoria'));
    await tester.pumpAndSettle();
    expect(find.text('Suono'), findsOneWidget);
  });

  testWidgets('i suggerimenti dei posti non superano il tetto e si scelgono',
      (tester) async {
    // Sei posti già usati che iniziano tutti per «Piazza»: il tetto è quattro.
    for (var i = 0; i < 6; i++) {
      await events.addEvent(
        title: 'Evento $i',
        start: DateTime(2026, 8, 1 + i, 9),
        end: DateTime(2026, 8, 1 + i, 10),
        location: 'Piazza numero $i',
      );
    }

    await apri(
      tester,
      ItemForm(type: ItemType.evento, day: DateTime(2026, 9, 14)),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Posizione'),
      'Piazza',
    );
    await tester.pumpAndSettle();

    final suggerimenti = find.byWidgetPredicate(
      (widget) =>
          widget is ActionChip &&
          widget.label is Text &&
          ((widget.label as Text).data ?? '').startsWith('Piazza'),
    );
    expect(suggerimenti, findsNWidgets(4));

    // Scegliendone uno il campo si riempie e i suggerimenti spariscono.
    await tester.tap(suggerimenti.first);
    await tester.pumpAndSettle();
    expect(suggerimenti, findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Titolo'), 'Prova');
    await salva(tester);

    final salvato = db.getEvents().map(Event.fromRow).last;
    expect(salvato.location, startsWith('Piazza numero'));
  });
}
