import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/updates/github_update.dart';
import 'package:planner/features/updates/update_controller.dart';
import 'package:planner/ui/mobile/updates_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('controllo manuale su schermo stretto con testo ingrandito',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 660);
    addTearDown(tester.view.reset);
    var nextCheck = Completer<GitHubUpdate?>();
    final controller = UpdateController(
      canCheck: () async => true,
      fetch: (_) => nextCheck.future,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const UpdatesPage(),
      ),
    ));

    final check = find.text('Controlla aggiornamenti');
    await tester.tap(check);
    await tester.pump();
    expect(find.text('Controllo in corso…'), findsOneWidget);
    nextCheck.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(
        find.text('Controllo non riuscito. Verifica la connessione e riprova.'),
        findsOneWidget);

    nextCheck = Completer<GitHubUpdate?>();
    await tester.tap(check);
    await tester.pump();
    nextCheck.complete(null);
    await tester.pumpAndSettle();
    expect(
        find.text('Nessun aggiornamento compatibile trovato'), findsOneWidget);
    final latest = find.text('Avviso all’apertura');
    await tester.scrollUntilVisible(latest, 150);
    expect(latest, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
