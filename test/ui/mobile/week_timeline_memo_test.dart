import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/theme/design_tokens.dart';
import 'package:planner/ui/mobile/week_day_headers.dart';
import 'package:planner/ui/mobile/week_timeline.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/ui/mobile/week_view.dart';

import '../../support/theme_providers.dart';

/// La tinta del giorno scelto sta **fuori** dalla griglia, e la griglia si ricorda.
///
/// Le due cose vanno insieme e sono una misura, non un gusto: cambiando giorno,
/// prima si ricostruivano le 168 celle della timeline e le corsie di tutti gli
/// eventi **dentro** il fotogramma dell'animazione — 20 ms di lavoro Dart letti dal
/// registro fotogrammi sul telefono. Con la tinta fuori e la griglia ricordata,
/// cambiando giorno si ricostruiscono solo tinta e intestazioni.
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

  Future<void> apri(WidgetTester tester, DateTime scelto) async {
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
                weekStart: DateTime(2026, 9, 14),
                selectedDay: giorno,
                occurrences: const [],
                // I todo non c'entrano con questa prova: la settimana si disegna
                // anche senza.
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

  /// Il rettangolo della tinta del giorno scelto.
  Rect tinta(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('tinta-giorno')));

  /// Il rettangolo della cella della data nell'intestazione.
  Rect cella(WidgetTester tester, int giorno) => tester.getRect(
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

  testWidgets('la tinta sta sotto la colonna del giorno scelto',
      (tester) async {
    await apri(tester, DateTime(2026, 9, 17));

    final dove = tinta(tester);
    expect(dove.left, closeTo(cella(tester, 17).left, 0.5));
    expect(dove.width, closeTo(colonna, 0.5));

    // Cambiando giorno la tinta si sposta con la colonna.
    //
    // Si tocca venerdi' 18 e non il 16: con la vista allineata su giovedi', il
    // mercoledi' e' a sinistra **fuori vista**, e il tocco cadrebbe a vuoto.
    // Questa prova e' nata sbagliata due volte proprio per quello: adesso dice
    // anche *che giorno* e' selezionato, cosi' un tocco a vuoto si vede subito
    // invece di far passare la prova per il motivo sbagliato.
    await tester.tap(
      find.descendant(
        of: find.byType(WeekDayHeaders),
        matching: find.text('18'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<WeekView>(find.byType(WeekView)).selectedDay,
      DateTime(2026, 9, 18),
      reason: 'il tocco deve aver cambiato il giorno selezionato',
    );

    final dopo = tinta(tester);
    expect(dopo.left, closeTo(cella(tester, 18).left, 0.5));
    expect(dopo.width, closeTo(colonna, 0.5));
  });

  testWidgets('cambiando giorno la griglia non si ricostruisce',
      (tester) async {
    await apri(tester, DateTime(2026, 9, 17));
    expect(find.byType(WeekTimeline), findsOneWidget);

    final prima = tester.widget<WeekTimeline>(find.byType(WeekTimeline));

    await tester.tap(
      find.descendant(
        of: find.byType(WeekDayHeaders),
        matching: find.text('18'),
      ),
    );
    await tester.pumpAndSettle();

    final dopo = tester.widget<WeekTimeline>(find.byType(WeekTimeline));
    expect(
      tester.widget<WeekView>(find.byType(WeekView)).selectedDay,
      DateTime(2026, 9, 18),
      reason: 'la memoria va provata con il giorno davvero cambiato',
    );
    expect(
      identical(prima, dopo),
      isTrue,
      reason:
          'cambiare giorno non deve ricostruire le 168 celle della griglia: '
          'era il fotogramma da 20 ms',
    );
  });
}
