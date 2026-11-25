import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/todos/domain/todo.dart';
import 'package:planner/ui/mobile/todo_card.dart';
import 'package:planner/ui/mobile/todo_compact_row.dart';
import 'package:planner/ui/shared/todo_time.dart';

import '../../support/theme_providers.dart';

/// L'orario dei todo **dove si vede**: la riga compatta (fascia di Mese e Giorno)
/// e la scheda (vista Todo).
///
/// Il riepilogo si prova qui e non in un test puro perché l'ora la scrive
/// `MaterialLocalizations`: in un test senza `BuildContext` non esiste. Le
/// asserzioni sono sulla **parola** («dalle», «entro le», il trattino), non sul
/// formato dell'ora, che cambia con la lingua del sistema (12 o 24 ore).
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [...themeProviders(db)],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Todo todo({int? start, int? end}) => Todo(
        id: 't1',
        title: 'Bolletta',
        dueDate: DateTime(2026, 9, 18),
        startMinutes: start,
        endMinutes: end,
      );

  group('il riepilogo', () {
    testWidgets('senza orario non dice niente', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) {
            final label = todoTimeLabel(context);
            return Text(label ?? 'solo data');
          },
        ),
      );
      expect(find.text('solo data'), findsOneWidget);
    });

    testWidgets('con entrambi: da…a', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => Text(
            todoTimeLabel(context, startMinutes: 8 * 60, endMinutes: 9 * 60) ??
                '',
          ),
        ),
      );
      expect(find.textContaining(' - '), findsOneWidget);
    });

    testWidgets('col solo inizio dice «dalle»', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => Text(
            todoTimeLabel(context, startMinutes: 8 * 60) ?? '',
          ),
        ),
      );
      expect(find.textContaining('dalle '), findsOneWidget);
    });

    testWidgets('con la sola fine dice «entro le»', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => Text(
            todoTimeLabel(context, endMinutes: 18 * 60) ?? '',
          ),
        ),
      );
      expect(find.textContaining('entro le '), findsOneWidget);
    });
  });

  testWidgets('la riga compatta mostra l\'orario accanto alla priorita\'',
      (tester) async {
    await pump(
      tester,
      TodoCompactRow(
        todo: todo(start: 8 * 60, end: 9 * 60),
        onToggle: () {},
      ),
    );

    expect(find.text('Bolletta'), findsOneWidget);
    expect(find.textContaining(' - '), findsOneWidget);
  });

  testWidgets('la riga compatta senza orario non aggiunge niente',
      (tester) async {
    await pump(
      tester,
      TodoCompactRow(todo: todo(), onToggle: () {}),
    );

    expect(find.text('Bolletta'), findsOneWidget);
    expect(find.textContaining(' - '), findsNothing);
    expect(find.textContaining('dalle '), findsNothing);
    expect(find.textContaining('entro le '), findsNothing);
  });

  testWidgets('la scheda mette l\'orario sulla riga della data',
      (tester) async {
    await pump(
      tester,
      TodoCard(
        todo: todo(start: 8 * 60),
        done: false,
        onToggle: () {},
        onTap: () {},
      ),
    );

    // Una sola riga di contorno: data e orario, separati dal punto mediano.
    expect(find.textContaining('dalle '), findsOneWidget);
    expect(find.textContaining(' · '), findsOneWidget);
  });
}
