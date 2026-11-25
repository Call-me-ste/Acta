// `Row` è anche un widget di Flutter: qui serve quello di sqlite3.
import 'package:flutter/material.dart' hide Row;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/mobile/calendar_page.dart';

/// Il precarico e la cache delle finestre: il primo cambio vista **non deve
/// leggere il database**.
///
/// Perché si conta invece di cronometrare: un tempo misurato su un emulatore non
/// vale niente (non ha GPU e oscilla col carico), mentre «quante query sono
/// partite» è un numero esatto e non dipende dalla macchina. È la stessa idea del
/// guardrail «salvare non rilegge tutto».
class _DbContata extends DatabaseService {
  int letture = 0;

  /// Le query di finestra: sono quelle che le viste fanno mentre si disegnano.
  @override
  List<Row> getEventsBetween(DateTime from, DateTime to) {
    letture++;
    return super.getEventsBetween(from, to);
  }

  @override
  List<Row> getRecurringEvents() {
    letture++;
    return super.getRecurringEvents();
  }
}

void main() {
  late _DbContata db;
  late EventProvider events;
  late TodoProvider todos;
  late AppSettingsController settings;

  setUp(() async {
    db = _DbContata();
    await db.init(dbPath: ':memory:');
    events = EventProvider(db);
    todos = TodoProvider(db);
    settings = AppSettingsController(db.settings)..load();

    // Un ricorrente e uno singolo: la ricorrenza è la parte che costa, ed è
    // quella che il precarico deve togliere dal gesto.
    await events.addEvent(
      title: 'Palestra',
      start: DateTime(2026, 9, 14, 18),
      end: DateTime(2026, 9, 14, 19),
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO',
      allDay: false,
    );
    await events.addEvent(
      title: 'Dentista',
      start: DateTime(2026, 9, 16, 9),
      end: DateTime(2026, 9, 16, 10),
    );
    await todos.addTodo(title: 'Spesa', dueDate: DateTime(2026, 9, 15));
  });

  tearDown(() => db.close());

  Widget harness() => MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<TodoProvider>.value(value: todos),
          ChangeNotifierProvider<AppSettingsController>.value(value: settings),
          ChangeNotifierProvider<PaletteController>.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
        ],
        child:
            MaterialApp(home: CalendarPage(initialDay: DateTime(2026, 9, 14))),
      );

  testWidgets('all\'apertura le finestre si calcolano una volta sola',
      (tester) async {
    await tester.pumpWidget(harness());
    // Il precaricamento scalda **due mesi per lato, uno per fotogramma**: si
    // lascia finire (una passata a vuoto per mese) e **poi** si guarda il conto.
    // Quello che questo test deve dire e' che il precarico copre tutto — mese,
    // settimana, giorni e i mesi vicini, che servono alle celle — cosi' nessun
    // gesto successivo legge il database.
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    final dopoIlPrimoFotogramma = db.letture;
    expect(
      dopoIlPrimoFotogramma,
      greaterThan(0),
      reason: 'aprendo l\'app i dati si leggono subito, non al primo gesto',
    );

    // Il fotogramma dopo, le altre due viste si costruiscono (il cambio le tiene
    // vive): se il precarico non avesse coperto le **loro** finestre, qui
    // partirebbero delle query.
    await tester.pump();
    expect(
      db.letture,
      dopoIlPrimoFotogramma,
      reason: 'costruire settimana e giorno non deve leggere il database',
    );

    // E nemmeno cambiare vista: le finestre sono già in cache.
    for (final vista in ['Settimana', 'Giorno', 'Mese']) {
      await tester.tap(find.text(vista));
      await tester.pumpAndSettle();
      expect(
        db.letture,
        dopoIlPrimoFotogramma,
        reason: 'dopo il cambio a «$vista» non si legge il database',
      );
    }
  });

  testWidgets('una scrittura invalida le finestre, e si ricalcolano',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    final dopoApertura = db.letture;

    // Un evento nuovo cambia quello che le viste mostrano: la cache deve cadere.
    await events.addEvent(
      title: 'Aperitivo',
      start: DateTime(2026, 9, 14, 20),
      end: DateTime(2026, 9, 14, 21),
    );
    await tester.pumpAndSettle();

    expect(
      db.letture,
      greaterThan(dopoApertura),
      reason: 'senza ricalcolo una vista mostrerebbe dati vecchi',
    );
  });
}
