import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/features/todos/todo_recurrence.dart';
import 'package:planner/features/widgets/domain/widget_payload.dart';
import 'package:planner/features/widgets/widget_contract.dart';
import 'package:planner/ui/shared/widget_guard.dart';

import '../../support/fake_widget_bridge.dart';

/// I momenti in cui i widget si **riscrivono**: l'avvio, una modifica, e il
/// ritorno in primo piano dopo che il widget ha spuntato qualcosa da solo.
///
/// Sono i tre che non si vedono: un widget fermo sulla giornata di ieri, o una
/// spunta fatta sul widget che l'app non sa di avere, si scoprono il giorno dopo.
/// Si provano con il ponte finto — il pacchetto è una mappa, si legge cosa c'è
/// dentro.
void main() {
  late DatabaseService db;
  late EventProvider eventi;
  late TodoProvider todo;
  late PaletteController palette;
  late CategoryController categorie;
  late AppSettingsController impostazioni;
  late FakeWidgetBridge ponte;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    eventi = EventProvider(db);
    todo = TodoProvider(db);
    palette = PaletteController(db)
      ..load()
      ..allineaPresets();
    categorie = CategoryController(db);
    impostazioni = AppSettingsController(db.settings)..load();
    ponte = FakeWidgetBridge();
  });

  tearDown(() => db.close());

  Future<void> monta(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: eventi),
          ChangeNotifierProvider<TodoProvider>.value(value: todo),
          ChangeNotifierProvider<PaletteController>.value(value: palette),
          ChangeNotifierProvider<CategoryController>.value(value: categorie),
          ChangeNotifierProvider<AppSettingsController>.value(
            value: impostazioni,
          ),
        ],
        child: MaterialApp(
          home: WidgetGuard(
            ponte: ponte,
            child: const Scaffold(body: SizedBox()),
          ),
        ),
      ),
    );
    // Il primo fotogramma: la guardia parte da lì (come nell'app).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// La giornata di oggi come l'ha pubblicata la guardia.
  Future<WidgetGiorno> oggi() async {
    final adesso = DateTime.now();
    final giorno = await ponte.leggiGiorno(
      DateTime(adesso.year, adesso.month, adesso.day),
    );
    expect(giorno, isNotNull, reason: 'la giornata di oggi deve esserci');
    return giorno!;
  }

  testWidgets(
      'al primo fotogramma scrive il pacchetto e riarma il cambio giorno',
      (tester) async {
    await monta(tester);

    expect(ponte.pubblicazioni, 1);
    expect(ponte.callback, isNotNull,
        reason: 'il callback dei tocchi si registra **prima** di tutto: se il '
            'widget viene toccato mentre l\'app parte, il plugin deve sapere chi '
            'chiamare');
    expect(ponte.cambiGiorno, 1,
        reason: 'l\'aggiornamento di mezzanotte si riarma a ogni scrittura');

    final giorno = await oggi();
    expect(giorno.etichetta, startsWith('Oggi · '));
    expect(giorno.stato, StatoDelGiorno.vuoto);
    expect(giorno.righe, isEmpty);

    // Il pacchetto copre otto giorni: con l'app chiusa il widget resta giusto.
    for (var scarto = 0; scarto < giorniNelPacchetto; scarto++) {
      final data = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day + scarto,
      );
      expect(await ponte.leggiGiorno(data), isNotNull,
          reason: 'manca il giorno $data');
    }

    expect(ponte.dati[chiaveTema], isNotNull,
        reason: 'i colori dei due temi viaggiano col pacchetto');
  });

  testWidgets('una modifica riscrive il pacchetto una volta sola',
      (tester) async {
    await monta(tester);
    expect(ponte.pubblicazioni, 1);

    await todo.addTodo(title: 'Spesa', dueDate: DateTime.now());
    // A un'ora tarda `adesso + 2h` cade **domani**, e il test falliva di notte
    // per un motivo che non c'entra col widget: l'evento va ancorato a oggi.
    final adesso = DateTime.now();
    final inizio = DateTime(adesso.year, adesso.month, adesso.day, 10);
    await eventi.addEvent(
      title: 'Dentista',
      start: inizio,
      end: inizio.add(const Duration(hours: 1)),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(ponte.pubblicazioni, 2,
        reason: 'due scritture di fila fanno **un** pacchetto (il rinvio)');
    final giorno = await oggi();
    expect(
      [for (final riga in giorno.righe) riga.titolo],
      containsAll(['Spesa', 'Dentista']),
    );
  });

  testWidgets('tornando in primo piano, se il widget ha scritto, si rilegge',
      (tester) async {
    await monta(tester);
    final prima = ponte.pubblicazioni;

    // Il widget spunta un todo mentre l'app è in secondo piano: la scrittura
    // arriva nel database **e** nell'istante del pacchetto, come fa il callback.
    await todo.addTodo(title: 'Spesa', dueDate: DateTime.now());
    await tester.pump(const Duration(seconds: 3));
    await todo.toggleTodo(todo.todos.single.id);
    ponte.dati[chiaveFattoIl] = '${DateTime.now().millisecondsSinceEpoch}';

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(ponte.pubblicazioni, greaterThan(prima),
        reason: 'la spunta fatta dal widget si vede: il pacchetto si rifà');
    final giorno = await oggi();
    expect(giorno.righe.single.fatto, isTrue,
        reason: 'e la riga dice che è fatta');
    expect(giorno.stato, StatoDelGiorno.tuttoFatto);
  });

  testWidgets('un risveglio senza scritture del widget non rifà niente',
      (tester) async {
    await monta(tester);
    final prima = ponte.pubblicazioni;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(ponte.pubblicazioni, prima,
        reason:
            'tornare in primo piano non è una modifica: si riscrive solo se '
            'il widget ha lavorato');
  });
}
