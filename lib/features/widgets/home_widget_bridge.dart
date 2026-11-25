import 'dart:async';
import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../../core/dev_flags.dart';
import 'domain/widget_mese.dart';
import 'domain/widget_payload.dart';
import 'widget_bridge.dart';
import 'widget_contract.dart';

/// L'unico file che importa `package:home_widget`.
///
/// Perché uno solo: il plugin sa **due** cose che non devono girare per l'app —
/// dove stanno i dati dei widget (le preferenze condivise con il processo del
/// launcher) e come si sveglia l'app da un tocco. Tutto il resto parla con
/// [WidgetBridge] e si prova con una finta.
///
/// I nomi dei metodi del plugin sono presi dai suoi sorgenti
/// (`pub-cache/hosted/pub.dev/home_widget-0.10.0`), non dalla documentazione
/// online: `saveWidgetData`/`getWidgetData`, `updateWidget`, `widgetClicked`,
/// `initiallyLaunchedFromHomeWidget`, `scheduleWidgetUpdates`,
/// `registerInteractivityCallback`.
class HomeWidgetBridge implements WidgetBridge {
  const HomeWidgetBridge();

  /// Il gruppo di dati: su Android è il nome dell'app, su iOS sarebbe l'app
  /// group. Uno solo per tutti e tre i widget (leggono lo stesso pacchetto).
  static const String _gruppo = 'com.callmeste.planner';

  @override
  Future<void> pubblica({
    required Map<DateTime, WidgetGiorno> giorni,
    required Map<DateTime, WidgetMese> mesi,
    required WidgetTema tema,
    required DateTime adesso,
  }) async {
    await _scrivi(chiaveTema, jsonEncode(tema.toJson()));
    for (final giorno in giorni.values) {
      await _scrivi(chiaveGiorno(giorno.data), jsonEncode(giorno.toJson()));
    }
    for (final mese in mesi.values) {
      await _scrivi(chiaveMese(mese.data), jsonEncode(mese.toJson()));
    }
    if (mesi.isNotEmpty) {
      // L'indice, non i dati: è quello che dice al Kotlin quale finestra è
      // valida adesso, così una chiave rimasta da un giro vecchio non viene
      // scambiata per il mese corrente.
      await _scrivi(
        chiaveMesiPubblicati,
        [for (final mese in mesi.values) annoMeseIso(mese.data)].join(','),
      );
    }
    if (giorni.isNotEmpty) {
      await _scrivi(chiaveUltimoGiorno, dataIso(giorni.keys.last));
    }
    await _scrivi(chiaveFattoIl, '${adesso.millisecondsSinceEpoch}');
    if (!devTools) {
      // L'«oggi finto» è un attrezzo della build di test e il Kotlin lo legge
      // senza sapere che build sia: se resta scritto da una prova, l'app
      // ufficiale mostrerebbe il giorno sbagliato. Qui lo si azzera.
      await _scrivi(chiaveOggiDiProva, '');
    }
    await _ridisegna();
  }

  @override
  Future<void> aggiornaGiorno(WidgetGiorno giorno) async {
    await _scrivi(chiaveGiorno(giorno.data), jsonEncode(giorno.toJson()));
    await _scrivi(chiaveFattoIl, '${DateTime.now().millisecondsSinceEpoch}');
    await _ridisegna();
  }

  @override
  Future<WidgetGiorno?> leggiGiorno(DateTime giorno) async {
    final testo = await _leggi(chiaveGiorno(giorno));
    if (testo == null || testo.isEmpty) return null;
    try {
      return WidgetGiorno.fromJson(
        (jsonDecode(testo) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      // Un pacchetto illeggibile non deve far saltare il callback di sfondo:
      // gira in un processo senza nessuno che guardi, e l'app lo riscrive alla
      // prima apertura.
      return null;
    }
  }

  @override
  Future<DateTime?> fattoIl() async {
    final testo = await _leggi(chiaveFattoIl);
    final millis = int.tryParse(testo ?? '');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Future<void> pianificaCambiGiorno(DateTime oggi) async {
    // Alle 00:05 dei prossimi giorni: il widget cambia giornata da solo, senza
    // aprire l'app. Sono **otto** orari e non uno perché il plugin riarma il
    // prossimo da sé: con uno solo, dopo la prima notte resterebbe senza.
    final orari = [
      for (var scarto = 1; scarto <= giorniNelPacchetto; scarto++)
        DateTime(
          oggi.year,
          oggi.month,
          oggi.day + scarto,
          minutiDelCambioGiorno ~/ 60,
          minutiDelCambioGiorno % 60,
        ),
    ];

    for (final provider in providerDeiWidget) {
      await HomeWidget.scheduleWidgetUpdates(
        orari,
        name: provider.nome,
        qualifiedAndroidName: provider.qualificato,
      );
    }
  }

  @override
  Future<void> registraCallback(FutureOr<void> Function(Uri?) callback) async {
    await HomeWidget.setAppGroupId(_gruppo);
    await HomeWidget.registerInteractivityCallback(callback);
  }

  @override
  Future<Uri?> uriDiAvvio() => HomeWidget.initiallyLaunchedFromHomeWidget();

  @override
  Stream<Uri?> get tocchi => HomeWidget.widgetClicked;

  @override
  Future<void> salvaCountdown({
    required int widgetId,
    required String eventoId,
    required String titolo,
    required DateTime data,
  }) async {
    await _scrivi(chiaveCountdownEvento(widgetId), eventoId);
    await _scrivi(chiaveCountdownTitolo(widgetId), titolo);
    await _scrivi(chiaveCountdownData(widgetId), dataIso(data));
    await _ridisegna();
  }

  /// I provider ridisegnano **tutti**: un tocco su uno solo (o un cambio di
  /// giorno) non deve lasciare gli altri con la data di ieri.
  Future<void> _ridisegna() async {
    for (final provider in providerDeiWidget) {
      await HomeWidget.updateWidget(
        name: provider.nome,
        // **Qualificato**: il plugin risolve `name` contro l'app id
        // (`"${packageName}.${className}"`), quindi il nome già qualificato
        // veniva raddoppiato e l'aggiornamento falliva con `PlatformException(-3)`.
        qualifiedAndroidName: provider.qualificato,
      );
    }
  }

  /// **Solo per la build di test**: dice ai widget di credere che oggi sia un
  /// altro giorno, e li ridisegna. Serve a provare il cambio di giornata senza
  /// aspettare mezzanotte (`lib/dev/widget_prova.dart`).
  ///
  /// Non sta nell'interfaccia `WidgetBridge` di proposito: non è una capacità
  /// dell'app, è un attrezzo da banco — e chi scrive l'app non deve poterlo
  /// chiamare per sbaglio.
  Future<void> fintaOggi(DateTime? giorno) async {
    await HomeWidget.saveWidgetData<String>(
      chiaveOggiDiProva,
      giorno == null ? '' : dataIso(giorno),
    );
    await _ridisegna();
  }

  Future<void> _scrivi(String chiave, String valore) =>
      HomeWidget.saveWidgetData<String>(chiave, valore);

  Future<String?> _leggi(String chiave) =>
      HomeWidget.getWidgetData<String>(chiave);
}
