import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/domain/event_occurrence.dart';
import 'package:planner/ui/mobile/week_day_headers.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/ui/mobile/week_view.dart';

import '../../support/theme_providers.dart';

/// Richiesta dell'utente: nella vista settimana, scegliendo un giorno (quello
/// accanto a oggi, o uno qualsiasi di un'altra settimana) la griglia deve
/// riportare l'orizzontale in modo che quel giorno si veda per intero, con i tre
/// pannelli allineati fra loro.
///
/// Prima non lo faceva: i tre pannelli condividevano l'offset (quindi le date
/// restavano sopra le loro colonne) ma nessuno lo riportava indietro quando
/// cambiava il giorno, e la vista restava scorsa dov'era.
///
/// La regola finale sta nella prova «il giorno scelto e' sempre visibile per
/// intero»: l'asse e' tornato a una settimana sola.
void main() {
  const gutter = AppSpacing.hourGutter;
  const larghezzaTela = 400.0;
  const giorniVisibili = WeekView.visibleDays;
  const colonna = (larghezzaTela - gutter) / giorniVisibili;

  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  /// Un evento che dura tutto il giorno: serve perche' la striscia «tutto il
  /// giorno» si costruisce solo se c'e' qualcosa dentro, e quella striscia e' il
  /// **terzo** pannello orizzontale da tenere allineato.
  EventOccurrence tuttoIlGiorno(DateTime giorno) {
    final inizio = DateTime(giorno.year, giorno.month, giorno.day, 9);
    return EventOccurrence(
      event: Event(
        id: 'all-day',
        title: 'Tutto il giorno',
        start: inizio,
        end: inizio.add(const Duration(hours: 1)),
        allDay: true,
      ),
      date: giorno,
      start: inizio,
      end: inizio.add(const Duration(hours: 1)),
    );
  }

  Future<void> apri(
      WidgetTester tester, DateTime lunedi, DateTime scelto) async {
    // Il giorno scelto lo possiede il genitore, non la vista (nella app e'
    // `CalendarPage`): il banco fa lo stesso, altrimenti toccare una data non
    // cambierebbe niente e la prova non proverebbe niente.
    var giorno = scelto;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: themeProviders(db),
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, aggiorna) => WeekView(
                weekStart: lunedi,
                selectedDay: giorno,
                occurrences: [tuttoIlGiorno(DateTime(2026, 9, 16))],
                // I todo non c'entrano con questa prova.
                todos: (perGiorno: const {}, modo: TodoInCalendario.pieni),
                onTap: (_) {},
                onDaySelected: (nuovo) => aggiorna(() => giorno = nuovo),
                onPreviousWeek: () {},
                onNextWeek: () {},
                onPickMonth: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Gli offset dei **tre** pannelli orizzontali (intestazioni, «tutto il
  /// giorno», griglia): devono essere tutti uguali, altrimenti date e colonne si
  /// staccano.
  List<double> offsetOrizzontali(WidgetTester tester) {
    final pannelli = tester.widgetList<SingleChildScrollView>(
      find.descendant(
        of: find.byType(WeekView),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    return [
      for (final pannello in pannelli)
        if (pannello.scrollDirection == Axis.horizontal)
          pannello.controller!.offset,
    ];
  }

  testWidgets('all\'apertura il giorno scelto e\' la prima colonna a sinistra',
      (tester) async {
    // Lunedi' 14 settembre 2026, ma il giorno scelto e' giovedi' 17: tre colonne
    // dopo l'inizio della settimana.
    await apri(tester, DateTime(2026, 9, 14), DateTime(2026, 9, 17));

    expect(offsetOrizzontali(tester), hasLength(3));
    for (final offset in offsetOrizzontali(tester)) {
      expect(offset, closeTo(3 * colonna, 0.5));
    }
  });

  testWidgets('toccando un altro giorno la sua colonna va a sinistra',
      (tester) async {
    await apri(tester, DateTime(2026, 9, 14), DateTime(2026, 9, 14));
    expect(offsetOrizzontali(tester).first, closeTo(0, 0.5));

    // Si tocca **mercoledi' 16**: la sua cella sta dentro lo schermo (a 3,5 giorni
    // visibili giovedi' e' gia' mezzo fuori, e un tocco fuori schermo non arriva).
    await tester.tap(
      find.descendant(
        of: find.byType(WeekDayHeaders),
        matching: find.text('16'),
      ),
    );
    await tester.pumpAndSettle();

    for (final offset in offsetOrizzontali(tester)) {
      expect(offset, closeTo(2 * colonna, 0.5));
    }

    // E la data del giorno scelto sta **sopra** la sua colonna, che ora e' la
    // prima: subito dopo la colonna degli orari.
    expect(
      tester
          .getRect(
            find
                .ancestor(
                  of: find.descendant(
                    of: find.byType(WeekDayHeaders),
                    matching: find.text('16'),
                  ),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .left,
      closeTo(gutter, 0.5),
    );
  });

  testWidgets(
      'il giorno scelto e\' sempre visibile per intero, e a sinistra quando '
      'c\'e\' posto', (tester) async {
    // La regola finale, dopo due tentativi sbagliati: l'asse e' **una settimana**
    // (allungato alla successiva l'utente ha visto «due settimane invece che
    // una»), il giorno scelto resta **visibile per intero**, e va nella prima
    // colonna quando c'e' spazio — cioe' per i primi quattro giorni. Da giovedi'
    // in poi, con tre giorni e mezzo visibili, lo spazio a destra finisce: la
    // vista si ferma al fondo e il giorno si vede comunque tutto.
    final lunedi = DateTime(2026, 9, 14);
    for (var i = 0; i < 7; i++) {
      final giorno = DateTime(2026, 9, 14 + i);
      await apri(tester, lunedi, giorno);

      final cella = tester.getRect(
        find
            .ancestor(
              of: find.descendant(
                of: find.byType(WeekDayHeaders),
                matching: find.text('${giorno.day}'),
              ),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(
        cella.left,
        greaterThanOrEqualTo(gutter - 0.5),
        reason: 'il giorno ${giorno.day} esce a sinistra',
      );
      expect(
        cella.right,
        lessThanOrEqualTo(larghezzaTela + 0.5),
        reason: 'il giorno ${giorno.day} esce a destra',
      );
      if (i <= 3) {
        expect(
          cella.left,
          closeTo(gutter, 0.5),
          reason: 'qui il giorno ${giorno.day} deve stare nella prima colonna',
        );
      }
    }
  });

  testWidgets('scorrere senza cambiare giorno non riallinea', (tester) async {
    await apri(tester, DateTime(2026, 9, 14), DateTime(2026, 9, 14));

    // Da un punto **dentro la vista**: il centro della griglia intera cade
    // fuori schermo (la griglia e' alta 24 ore), e li' il gesto non arriva.
    await tester.dragFrom(const Offset(300, 500), const Offset(-80, 0));
    await tester.pumpAndSettle();

    final offset = offsetOrizzontali(tester);
    expect(
      offset.first,
      greaterThan(50),
      reason: 'lo scorrimento deve essere avvenuto davvero',
    );
    expect(
      offset.toSet(),
      hasLength(1),
      reason: 'i tre pannelli devono restare allineati fra loro',
    );
  });
}
