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

/// Le date della settimana devono stare **sopra le loro colonne**: la prima dopo
/// la colonna delle ore, e ogni cella larga quanto la colonna del giorno che
/// intestano.
///
/// Il difetto trovato: l'intestazione partiva da x=0 mentre la griglia partiva da
/// x=40 (la colonna degli orari), quindi le date erano sfalsate di 40 px e la
/// prima finiva sopra l'orario, «oltre il bordo sinistro della tabella».
void main() {
  /// La colonna delle ore, dal token condiviso con la vista giorno.
  const gutter = AppSpacing.hourGutter;

  /// La larghezza della tela del test.
  const larghezzaTela = 400.0;

  /// Quanti giorni entrano nello schermo: la stessa costante di `week_view.dart`.
  const giorniVisibili = WeekView.visibleDays;

  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  EventOccurrence evento(DateTime giorno) {
    final inizio = DateTime(giorno.year, giorno.month, giorno.day, 9);
    return EventOccurrence(
      event: Event(
        id: 'e-${giorno.day}',
        title: 'Evento ${giorno.day}',
        start: inizio,
        end: inizio.add(const Duration(hours: 1)),
      ),
      date: giorno,
      start: inizio,
      end: inizio.add(const Duration(hours: 1)),
    );
  }

  Future<void> apri(WidgetTester tester, {double scala = 1}) async {
    final lunedi = DateTime(2026, 9, 14);
    await tester.binding.setSurfaceSize(const Size(400, 800));
    tester.platformDispatcher.textScaleFactorTestValue = scala;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: themeProviders(db),
        child: MaterialApp(
          home: Scaffold(
            body: WeekView(
              weekStart: lunedi,
              selectedDay: lunedi,
              occurrences: [evento(DateTime(2026, 9, 16))],
              // I todo non c'entrano con questa prova.
              todos: (perGiorno: const {}, modo: TodoInCalendario.pieni),
              onTap: (_) {},
              onDaySelected: (_) {},
              onPreviousWeek: () {},
              onNextWeek: () {},
              onPickMonth: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Il rettangolo della **cella** di un giorno nell'intestazione: la cella e'
  /// l'`InkWell` che contiene il numero, non il numero stesso (il numero e' largo
  /// quanto le sue cifre, la cella quanto la colonna).
  Rect cella(WidgetTester tester, int giorno) {
    return tester.getRect(
      find
          .ancestor(
            of: find.descendant(
              of: find.byType(WeekDayHeaders),
              matching: find.text('$giorno'),
            ),
            matching: find.byType(InkWell),
          )
          .first,
    );
  }

  testWidgets('la prima cella comincia dopo la colonna delle ore',
      (tester) async {
    await apri(tester);

    expect(
      cella(tester, 14).left,
      closeTo(gutter, 0.5),
      reason: 'le date non devono passare sopra la colonna degli orari',
    );
  });

  testWidgets('le celle sono larghe come le colonne dei giorni',
      (tester) async {
    await apri(tester);

    const attesa = (larghezzaTela - gutter) / giorniVisibili;
    for (var giorno = 14; giorno <= 20; giorno++) {
      final rettangolo = cella(tester, giorno);
      expect(rettangolo.width, closeTo(attesa, 1));
      expect(
        rettangolo.left,
        closeTo(gutter + (giorno - 14) * attesa, 1),
        reason: 'la cella del $giorno sta sopra la sua colonna',
      );
    }
  });

  testWidgets('a testo ingrandito le date restano allineate', (tester) async {
    await apri(tester, scala: 1.3);
    expect(cella(tester, 14).left, closeTo(gutter, 0.5));
  });

  testWidgets('a testo 2.0 le date restano allineate', (tester) async {
    await apri(tester, scala: 2.0);
    expect(cella(tester, 14).left, closeTo(gutter, 0.5));
  });
}
