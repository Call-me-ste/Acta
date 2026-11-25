import 'dart:async';
import 'dart:convert';

import 'package:planner/features/widgets/domain/widget_mese.dart';
import 'package:planner/features/widgets/domain/widget_payload.dart';
import 'package:planner/features/widgets/widget_bridge.dart';
import 'package:planner/features/widgets/widget_contract.dart';

/// Il ponte **finto**: tiene il pacchetto in una mappa, come fa la schermata home,
/// e passa dal JSON come il ponte vero.
///
/// Il giro in JSON non è pedanteria: `toJson`/`fromJson` sono il contratto fra
/// Dart e il renderer Kotlin, e una divergenza fra i due lati si vedrebbe solo sul
/// telefono (o mai). Qui si vedrebbe in un test.
class FakeWidgetBridge implements WidgetBridge {
  /// Quel che «la schermata home» ha adesso, per chiave.
  final Map<String, String> dati = {};

  int pubblicazioni = 0;
  int aggiornamenti = 0;
  int ridisegni = 0;
  int cambiGiorno = 0;

  /// L'URI con cui l'app è stata aperta (se il test lo decide).
  Uri? avvio;

  /// Il callback registrato per i tocchi a app chiusa.
  FutureOr<void> Function(Uri?)? callback;

  @override
  Stream<Uri?> get tocchi => const Stream<Uri?>.empty();

  /// Mette in «schermata home» la giornata, come farebbe l'app.
  void preparaGiorno(WidgetGiorno giorno) {
    dati[chiaveGiorno(giorno.data)] = jsonEncode(giorno.toJson());
  }

  /// Mette in «schermata home» il mese, indice compreso.
  void preparaMese(WidgetMese mese) {
    final primo = DateTime(mese.anno, mese.mese);
    dati[chiaveMese(primo)] = jsonEncode(mese.toJson());
    final pubblicati = (dati[chiaveMesiPubblicati] ?? '')
        .split(',')
        .where((voce) => voce.isNotEmpty)
        .toList();
    final annoMese = annoMeseIso(primo);
    if (!pubblicati.contains(annoMese)) pubblicati.add(annoMese);
    dati[chiaveMesiPubblicati] = pubblicati.join(',');
  }

  @override
  Future<void> pubblica({
    required Map<DateTime, WidgetGiorno> giorni,
    required Map<DateTime, WidgetMese> mesi,
    required WidgetTema tema,
    required DateTime adesso,
  }) async {
    pubblicazioni++;
    dati[chiaveTema] = jsonEncode(tema.toJson());
    dati[chiaveMesiPubblicati] = '';
    for (final giorno in giorni.values) {
      preparaGiorno(giorno);
    }
    for (final mese in mesi.values) {
      preparaMese(mese);
    }
    if (giorni.isNotEmpty) {
      dati[chiaveUltimoGiorno] = dataIso(giorni.keys.last);
    }
    dati[chiaveFattoIl] = '${adesso.millisecondsSinceEpoch}';
    ridisegni++;
  }

  @override
  Future<void> aggiornaGiorno(WidgetGiorno giorno) async {
    aggiornamenti++;
    preparaGiorno(giorno);
    dati[chiaveFattoIl] = '${DateTime.now().millisecondsSinceEpoch}';
    ridisegni++;
  }

  @override
  Future<WidgetGiorno?> leggiGiorno(DateTime giorno) async {
    final testo = dati[chiaveGiorno(giorno)];
    if (testo == null) return null;
    return WidgetGiorno.fromJson(
      (jsonDecode(testo) as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<DateTime?> fattoIl() async {
    final millis = int.tryParse(dati[chiaveFattoIl] ?? '');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Future<void> pianificaCambiGiorno(DateTime oggi) async => cambiGiorno++;

  @override
  Future<void> registraCallback(FutureOr<void> Function(Uri?) callback) async {
    this.callback = callback;
  }

  @override
  Future<Uri?> uriDiAvvio() async => avvio;

  @override
  Future<void> salvaCountdown({
    required int widgetId,
    required String eventoId,
    required String titolo,
    required DateTime data,
  }) async {
    dati[chiaveCountdownEvento(widgetId)] = eventoId;
    dati[chiaveCountdownTitolo(widgetId)] = titolo;
    dati[chiaveCountdownData(widgetId)] = dataIso(data);
    ridisegni++;
  }
}
