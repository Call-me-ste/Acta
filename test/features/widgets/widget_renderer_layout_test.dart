import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/ui/shared/widget_countdown.dart';

void main() {
  test('le righe del giorno restano leggibili e toccabili', () {
    final riga = File('android/app/src/main/res/layout/widget_riga.xml')
        .readAsStringSync();
    expect(riga, contains('android:layout_height="48dp"'));
    expect(riga, contains('@+id/riga_spunta'));
    expect(riga, contains('android:layout_width="48dp"'));
    expect(riga, contains('android:textSize="16sp"'));
    expect(riga, contains('android:textSize="14sp"'));

    final planner = File('android/app/src/main/res/layout/widget_planner.xml')
        .readAsStringSync();
    for (final id in [
      'widget_intestazione',
      'widget_titolo',
      'widget_conteggi',
      'widget_giorni',
      'widget_righe',
      'widget_stato_riga',
    ]) {
      expect(planner, contains('@+id/$id'), reason: id);
    }
    expect(planner, contains('android:layout_height="44dp"'));
    expect(planner, contains('android:layout_height="48dp"'));
    expect(planner, contains('android:textSize="18sp"'));
    expect(planner, contains('android:textSize="12sp"'));
  });

  test('il mese ha tre vestiti, tutti a righe pesate', () {
    final sorgente = File(
      'android/app/src/main/kotlin/com/callmeste/planner/widget/WidgetMeseRenderer.kt',
    ).readAsStringSync();
    expect(sorgente, contains('enum class Variante'));
    expect(sorgente, contains('MESE_4X2'));
    expect(sorgente, contains('MESE_4X4'));
    expect(sorgente, contains('MESE_2X2'));
    expect(sorgente, contains('mese.settimane.coerceIn(5, 6)'));
    expect(sorgente, contains('addView(R.id.mese_griglia, riga)'));

    // Il disegno nuovo: Inter rasterizzato, non TextView col font del launcher.
    final nuovo = File(
      'android/app/src/main/kotlin/com/callmeste/planner/widget/WidgetMeseNuovoRenderer.kt',
    ).readAsStringSync();
    expect(nuovo, contains('WidgetText.scrivi'));
    expect(nuovo, contains('WidgetText.SEMIBOLD'));
    expect(nuovo, contains('for (settimana in 0 until 6)'));
    expect(nuovo, contains('mese_eventi'));

    final testo = File(
      'android/app/src/main/kotlin/com/callmeste/planner/widget/WidgetText.kt',
    ).readAsStringSync();
    expect(testo, contains('Inter-SemiBold.ttf'));
    expect(testo, contains('Bitmap.createBitmap'));

    for (var i = 0; i < 6; i++) {
      final riga = File(
        'android/app/src/main/res/layout/widget_mese_riga_g$i.xml',
      ).readAsStringSync();
      expect(riga, contains('android:id="@+id/mese_riga_g$i"'));
      expect(riga, contains('android:layout_height="0dp"'));
      expect(riga, contains('android:layout_weight="1"'));
    }

    final cellaBitmap =
        File('android/app/src/main/res/layout/widget_mese_cella_bitmap.xml')
            .readAsStringSync();
    expect(cellaBitmap, contains('@+id/cella_immagine'));
    expect(cellaBitmap, isNot(contains('android:text=')));

    final mini =
        File('android/app/src/main/res/layout/widget_mese_cella_mini.xml')
            .readAsStringSync();
    expect(mini, contains('android:textSize="8sp"'));

    final quattroPerDue =
        File('android/app/src/main/res/layout/widget_mese.xml')
            .readAsStringSync();
    expect(quattroPerDue, isNot(contains('@+id/mese_agenda')));
    expect(quattroPerDue, contains('@+id/mese_griglia'));
    expect(quattroPerDue, contains('@+id/mese_eyebrow'));
    expect(quattroPerDue, contains('@+id/mese_giorno_numero'));
    // Niente frecce: il 4x2 si centra sul giorno e il mese si cambia dall'app.
    expect(quattroPerDue, isNot(contains('@+id/mese_indietro')));
    expect(quattroPerDue, isNot(contains('@+id/mese_avanti')));
    expect(quattroPerDue, contains('android:gravity="center"'));

    final info = File('android/app/src/main/res/xml/widget_mese_info.xml')
        .readAsStringSync();
    expect(info, contains('android:targetCellWidth="4"'));
    expect(info, contains('android:targetCellHeight="2"'));
    expect(info, isNot(contains('android:configure=')));

    final grandeInfo =
        File('android/app/src/main/res/xml/widget_mese_grande_info.xml')
            .readAsStringSync();
    expect(grandeInfo, contains('android:targetCellWidth="4"'));
    expect(grandeInfo, contains('android:targetCellHeight="4"'));
    expect(grandeInfo, contains('android:configure='));
    expect(grandeInfo, contains('android:resizeMode="none"'));

    final grandeLayout =
        File('android/app/src/main/res/layout/widget_mese_grande.xml')
            .readAsStringSync();
    for (final parte in [
      '@+id/mese_griglia',
      '@+id/mese_divisore',
      '@+id/mese_giorno_titolo',
      '@+id/mese_conteggio',
      '@+id/mese_nuovo',
      '@+id/mese_eventi',
      '@+id/mese_todo_righe',
      '@+id/mese_todo_barra',
    ]) {
      expect(grandeLayout, contains(parte), reason: parte);
    }
    expect(grandeLayout, isNot(contains('<ListView')));
    expect(grandeLayout, isNot(contains('@+id/mese_agenda')));

    final miniInfo =
        File('android/app/src/main/res/xml/widget_mese_compatto_info.xml')
            .readAsStringSync();
    expect(miniInfo, contains('android:targetCellWidth="2"'));
    expect(miniInfo, contains('android:targetCellHeight="2"'));
  });

  test('i To-Do hanno tre modalità e una configurazione con anteprima', () {
    final kit = File(
      'android/app/src/main/kotlin/com/callmeste/planner/widget/WidgetKit.kt',
    ).readAsStringSync();
    expect(kit, contains('enum class TodoMode'));
    expect(kit, contains('NESSUNO'));
    expect(kit, contains('COMPATTI'));
    expect(kit, contains('ESTESI'));
    expect(kit, contains('widget_todo_mode_'));

    final config = File(
      'android/app/src/main/kotlin/com/callmeste/planner/widget/WidgetConfigActivity.kt',
    ).readAsStringSync();
    for (final testo in [
      'Non mostrare i To do',
      'To do compatti',
      'To do estesi',
      'ANTEPRIMA',
      'Salva',
    ]) {
      expect(config, contains(testo), reason: testo);
    }

    final compatto = File(
      'android/app/src/main/res/layout/widget_riga_compatta.xml',
    ).readAsStringSync();
    expect(compatto, contains('@+id/riga_spunta'));
    expect(compatto, contains('@+id/riga_titolo'));
    expect(compatto, isNot(contains('@+id/riga_ora')));

    final eventiCompatto = File(
      'android/app/src/main/res/layout/widget_eventi_riga_compatta.xml',
    ).readAsStringSync();
    expect(eventiCompatto, contains('@+id/evento_riga_todo'));

    final quattroPerDue =
        File('android/app/src/main/res/layout/widget_mese.xml')
            .readAsStringSync();
    expect(quattroPerDue, contains('@+id/mese_griglia'));
    expect(quattroPerDue, isNot(contains('@+id/mese_agenda')));
    // Il 4x2 non ha più frecce: mese, giorno e numero sono centrati.
    expect(quattroPerDue, isNot(contains('@+id/mese_indietro')));
    expect(quattroPerDue, contains('@+id/mese_giorno_numero'));

    final serviceMese = File(
      'android/app/src/main/kotlin/com/callmeste/planner/widget/MeseWidgetService.kt',
    ).readAsStringSync();
    expect(serviceMese, contains('RemoteViewsService'));
    expect(serviceMese, contains('EXTRA_SCELTO'));
    expect(serviceMese, contains('EXTRA_CONTENUTO'));
  });

  test('Agenda 4x4: striscia dei giorni, lista e testi in bitmap', () {
    final layout = File('android/app/src/main/res/layout/widget_agenda.xml')
        .readAsStringSync();
    for (final parte in [
      '@+id/agenda_titolo',
      '@+id/agenda_indietro',
      '@+id/agenda_avanti',
      '@+id/agenda_nuovo',
      '@+id/agenda_striscia',
      '@+id/agenda_eventi',
      '@+id/agenda_todo_righe',
      '@+id/agenda_todo_barra',
    ]) {
      expect(layout, contains(parte), reason: parte);
    }
    expect(layout, isNot(contains('<ListView')));

    final cella = File(
      'android/app/src/main/res/layout/widget_agenda_cella.xml',
    ).readAsStringSync();
    expect(cella, contains('@+id/agenda_cella_immagine'));
    expect(cella, isNot(contains('android:text=')));

    final renderer = File(
      'android/app/src/main/kotlin/com/callmeste/planner/widget/AgendaWidgetRenderer.kt',
    ).readAsStringSync();
    expect(renderer, contains('WidgetText.scrivi'));
    expect(renderer, contains('WidgetText.SEMIBOLD'));
    expect(renderer, contains('rigaEvento'));
    expect(renderer, contains('rigaTodo'));
    expect(renderer, contains('barraTodo'));
    expect(renderer, contains('AZIONE_SETTIMANA'));
    expect(renderer, contains('lunediDi'));

    final info = File('android/app/src/main/res/xml/widget_oggi_info.xml')
        .readAsStringSync();
    expect(info, contains('@layout/widget_agenda'));
    expect(info, contains('android:targetCellWidth="4"'));
    expect(info, contains('android:targetCellHeight="4"'));
    expect(info, contains('android:configure='));
  });

  test('eventi 2x2 è una collection vera, con testata fissa e vuoto a +', () {
    final layout = File('android/app/src/main/res/layout/widget_eventi.xml')
        .readAsStringSync();
    expect(layout, contains('<ListView'));
    expect(layout, contains('@+id/eventi_lista'));
    expect(layout, contains('@+id/eventi_vuoto'));
    expect(layout, contains('@+id/eventi_etichetta'));
    expect(layout, contains('Aggiungi evento'));

    final riga = File(
      'android/app/src/main/res/layout/widget_eventi_riga.xml',
    ).readAsStringSync();
    expect(riga, contains('@+id/evento_riga_radice'));
    expect(riga, contains('@+id/evento_riga_titolo'));

    final service = File(
      'android/app/src/main/kotlin/com/callmeste/planner/widget/EventiWidgetProvider.kt',
    ).readAsStringSync();
    expect(service, contains('RemoteViewsService'));
    expect(service, contains('RemoteViewsFactory'));
    expect(service, contains('setRemoteAdapter'));
    expect(service, contains('notifyAppWidgetViewDataChanged'));

    final info = File('android/app/src/main/res/xml/widget_eventi_info.xml')
        .readAsStringSync();
    expect(info, contains('android:targetCellWidth="2"'));
    expect(info, contains('android:targetCellHeight="2"'));
    expect(info, contains('android:configure='));
  });

  test('countdown e configurazione sono dichiarati e coerenti', () {
    final countdown =
        File('android/app/src/main/res/layout/widget_countdown.xml')
            .readAsStringSync();
    expect(countdown, contains('@+id/countdown_titolo'));
    expect(countdown, contains('@+id/countdown_numero'));
    expect(countdown, contains('@+id/countdown_sotto'));
    expect(countdown, contains('@+id/countdown_piu'));

    final info = File('android/app/src/main/res/xml/widget_countdown_info.xml')
        .readAsStringSync();
    expect(info, contains('android:targetCellWidth="2"'));
    expect(info, contains('android:targetCellHeight="2"'));

    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final nome in [
      'MeseWidgetProvider',
      'MeseGrandeWidgetProvider',
      'MeseCompattoWidgetProvider',
      'OggiWidgetProvider',
      'TodoWidgetProvider',
      'EventiWidgetProvider',
      'CountdownWidgetProvider',
      'WidgetConfigActivity',
      'EventiWidgetService',
      'WidgetGiornoReceiver',
    ]) {
      expect(manifest, contains(nome), reason: nome);
    }

    final oggi = File('android/app/src/main/res/xml/widget_oggi_info.xml')
        .readAsStringSync();
    expect(oggi, contains('android:configure='));
    expect(oggi, contains('android:targetCellHeight="4"'));
  });

  test('le etichette del countdown non perdono il giorno', () {
    expect(etichettaCountdown(DateTime(2026, 10, 24)), '24 ott');
    expect(etichettaCountdown(DateTime(2027, 1, 3)), '3 gen 2027');
  });
}
