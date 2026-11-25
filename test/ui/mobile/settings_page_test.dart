import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/notifications/notification_settings_controller.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/ui/mobile/settings_page.dart';

/// Le impostazioni a **due velocità**: quello che si vede sempre — le sei righe
/// di tutti i giorni — e quello che compare solo accendendo «Modalità esperta».
///
/// Perché conta: la pagina è cresciuta fino a diventare un elenco di manopole, e
/// il metro è «ci si deve raccapezzare anche chi non ha voglia di impostare
/// niente». Qui si pretende che in Standard **non** ci siano le due preferenze da
/// nerd (che prima non erano raggiungibili da nessuna parte) e che accendendo
/// l'Esperto si vedano e scrivano davvero.
void main() {
  late DatabaseService db;
  late AppSettingsController impostazioni;
  late CategoryController categorie;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    impostazioni = AppSettingsController(db.settings)..load();
    categorie = CategoryController(db);
  });

  tearDown(() => db.close());

  Future<void> apri(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: db),
          ChangeNotifierProvider.value(value: impostazioni),
          ChangeNotifierProvider.value(value: categorie),
          ChangeNotifierProvider.value(
            value: NotificationSettingsController(db.settings)..load(),
          ),
          ChangeNotifierProvider.value(
            value: PaletteController(db)
              ..load()
              ..allineaPresets(),
          ),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Le ultime righe della pagina stanno sotto la piega: l'elenco è pigro, e
  /// senza scorrere non esisterebbero nemmeno nell'albero.
  Future<void> vaiInFondo(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
  }

  testWidgets('Aggiornamenti apre versione e novità anche offline',
      (tester) async {
    await apri(tester);
    await vaiInFondo(tester);
    await tester.tap(find.text('Aggiornamenti'));
    await tester.pumpAndSettle();
    expect(find.text('Versione installata'), findsOneWidget);
    expect(find.text('Cosa c’è di nuovo'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(
            find.widgetWithText(ListTile, 'Controlla aggiornamenti'),
          )
          .onTap,
      isNull,
    );
  });

  testWidgets('vista semplice: righe quotidiane e opzioni chiuse',
      (tester) async {
    await apri(tester);

    for (final testo in [
      'Aspetto',
      'Organizzazione',
      'Categorie',
      'Priorità',
      'To do nel calendario',
      'Avvisi',
      'Notifiche',
      'Dati e backup',
      'Copie di sicurezza',
      'Importa eventi',
    ]) {
      expect(find.text(testo), findsWidgets, reason: 'manca «$testo»');
    }

    expect(find.text('Sincronizzazione'), findsNothing);
    expect(find.text('Google Drive'), findsNothing);
    await vaiInFondo(tester);
    expect(
      find.byKey(const ValueKey('impostazioni-opzioni-avanzate')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('modalita-esperta')), findsNothing);
    expect(find.byKey(const ValueKey('impostazioni-animazioni')), findsNothing);
    expect(find.byKey(const ValueKey('impostazioni-scaduti')), findsNothing);
    expect(find.byKey(const ValueKey('notifica-attive')), findsNothing,
        reason:
            'le notifiche stanno nella loro pagina, non in mezzo alle altre');
    expect(find.text('Compatta'), findsOneWidget,
        reason: 'la riga dei todo dice il valore, senza le tre voci aperte');
  });

  testWidgets('le opzioni locali si aprono e salvano le preferenze',
      (tester) async {
    await apri(tester);
    await vaiInFondo(tester);

    await tester.tap(
      find.byKey(const ValueKey('impostazioni-opzioni-avanzate')),
    );
    await tester.pumpAndSettle();

    expect(impostazioni.advancedMode, isFalse,
        reason: 'le opzioni locali non toccano la preferenza legacy');
    await vaiInFondo(tester);
    expect(
        find.byKey(const ValueKey('impostazioni-animazioni')), findsOneWidget);
    expect(find.byKey(const ValueKey('impostazioni-scaduti')), findsOneWidget);
    expect(find.text('30 giorni'), findsOneWidget,
        reason: 'la finestra degli scaduti dice il valore di partenza');

    // Le animazioni: l'interruttore scrive davvero.
    await tester.tap(find.byKey(const ValueKey('impostazioni-animazioni')));
    await tester.pumpAndSettle();
    expect(impostazioni.animationsEnabled, isFalse);

    // La finestra degli scaduti: quattro scelte, e quella toccata si salva.
    await tester.tap(find.byKey(const ValueKey('impostazioni-scaduti')));
    await tester.pumpAndSettle();
    for (final giorni in [7, 15, 30, 90]) {
      expect(find.byKey(ValueKey('azione-$giorni')), findsOneWidget,
          reason: 'manca la scelta «$giorni giorni»');
    }
    await tester.tap(find.byKey(const ValueKey('azione-7')));
    await tester.pumpAndSettle();

    expect(impostazioni.overdueWindowDays, 7);
    expect(find.text('7 giorni'), findsOneWidget);
  });

  testWidgets('la riga Categorie dice quante ce ne sono', (tester) async {
    await apri(tester);
    expect(find.text('Le etichette di eventi e To do'), findsOneWidget,
        reason: 'con la libreria vuota la riga spiega a cosa servono');

    await categorie.create(name: 'Casa');
    await tester.pumpAndSettle();
    expect(find.text('1 etichetta'), findsOneWidget);

    await categorie.create(name: 'Lavoro');
    await tester.pumpAndSettle();
    expect(find.text('2 etichette'), findsOneWidget);
  });
}
