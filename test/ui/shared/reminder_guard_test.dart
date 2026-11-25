import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:planner/features/notifications/notification_scheduler.dart';
import 'package:planner/features/notifications/notification_settings_controller.dart';
import 'package:planner/features/todos/todo_provider.dart';
import 'package:planner/ui/shared/reminder_guard.dart';

import '../../support/fake_notification_sink.dart';

/// I tre momenti in cui gli avvisi si **ricalcolano**: l'avvio, una modifica,
/// il ritorno in primo piano.
///
/// Sono esattamente i tre che non si vedono a occhio: un avviso che non arriva
/// si scopre il giorno in cui serviva, e un avviso pianificato con l'ora vecchia
/// suona quando non deve. Si provano con il sink finto — gli avvisi sono una
/// mappa, si legge cosa c'è e quando.
void main() {
  late DatabaseService db;
  late NotificationSettingsController notifiche;
  late FakeNotificationSink sink;
  late EventProvider eventi;
  late TodoProvider todo;
  late NotificationScheduler pianificatore;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    notifiche = NotificationSettingsController(db.settings)..load();
    notifiche.setAttive(true);
    sink = FakeNotificationSink();
    eventi = EventProvider(db);
    todo = TodoProvider(db);
    pianificatore = NotificationScheduler(
      db,
      notifiche,
      sink,
      // Orologio **finto**: con quello vero questa prova cambierebbe esito a
      // mezzanotte (l'evento di oggi alle 18 diventa passato), che è il modo
      // classico in cui un test comincia a fallire da solo.
      adesso: () => DateTime(2026, 9, 24, 12),
      debounce: const Duration(milliseconds: 20),
    );
  });

  tearDown(() {
    pianificatore.dispose();
    db.close();
  });

  Future<void> monta(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventProvider>.value(value: eventi),
          ChangeNotifierProvider<TodoProvider>.value(value: todo),
          ChangeNotifierProvider<NotificationSettingsController>.value(
            value: notifiche,
          ),
          Provider<NotificationScheduler>.value(value: pianificatore),
        ],
        child: const MaterialApp(home: ReminderGuard(child: SizedBox())),
      ),
    );
    // Il callback di fine fotogramma passa da qui.
    await tester.pump();
  }

  testWidgets('all\'avvio gli avvisi si allineano, una volta sola',
      (tester) async {
    db.insertEvent({
      'id': 'e1',
      'title': 'Dentista',
      'start_time': DateTime(2026, 9, 24, 18).millisecondsSinceEpoch,
      'end_time': DateTime(2026, 9, 24, 19).millisecondsSinceEpoch,
    });

    await monta(tester);

    expect(sink.preparazioni, 1, reason: 'un giro all\'avvio');
    expect(sink.avvisi, hasLength(1), reason: 'il promemoria dell\'evento');

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(sink.preparazioni, 1, reason: 'una tantum, non a ogni fotogramma');
  });

  testWidgets('una modifica chiede un giro (uno solo, dopo il debounce)',
      (tester) async {
    await monta(tester);
    final giriAllAvvio = sink.preparazioni;

    // Due scritture di fila: un todo e un evento.
    todo.addTodo(
      title: 'Spesa',
      dueDate: DateTime(2026, 9, 26),
    );
    db.insertEvent({
      'id': 'e1',
      'title': 'Dentista',
      'start_time': DateTime(2026, 9, 24, 18).millisecondsSinceEpoch,
      'end_time': DateTime(2026, 9, 24, 19).millisecondsSinceEpoch,
    });
    eventi.reload();

    // Il debounce è 20 ms: si fa passare il tempo perché scatti.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(
      sink.preparazioni,
      giriAllAvvio + 1,
      reason: 'due modifiche, un giro solo (il debounce le unisce)',
    );
    expect(
      sink.avvisi.values.map((a) => a.kind.name).toSet(),
      containsAll(<String>['todo', 'evento']),
      reason: 'e il giro porta **entrambe** le modifiche',
    );
  });

  testWidgets('tornando in primo piano si ricalcola', (tester) async {
    await monta(tester);
    final giriAllAvvio = sink.preparazioni;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(sink.preparazioni, giriAllAvvio + 1);
  });
}
