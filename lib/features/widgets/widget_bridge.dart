import 'dart:async';

import 'domain/widget_mese.dart';
import 'domain/widget_payload.dart';

/// Chi scrive **davvero** il pacchetto dei widget e ridisegna la schermata home:
/// l'unico punto in cui l'app parla col plugin (`home_widget`).
///
/// Esiste per la stessa ragione del `NotificationSink`: senza, la logica del
/// widget (cosa mostrare, cosa succede toccando) vorrebbe un telefono per essere
/// provata. L'implementazione vera è `HomeWidgetBridge` — **l'unico file che
/// importa il plugin** — e nei test c'è una finta
/// (`test/support/fake_widget_bridge.dart`).
abstract interface class WidgetBridge {
  /// Scrive **tutto** il pacchetto (tema, otto giorni, i tre mesi, l'indice dei
  /// mesi pubblicati, istante) e ridisegna i quattro widget. È la strada della
  /// guardia, quando l'app è aperta.
  Future<void> pubblica({
    required Map<DateTime, WidgetGiorno> giorni,
    required Map<DateTime, WidgetMese> mesi,
    required WidgetTema tema,
    required DateTime adesso,
  });

  /// Riscrive **una** giornata e ridisegna: è la strada del callback di sfondo,
  /// dopo una spunta. Segna anche l'istante della scrittura, così l'app che torna
  /// in primo piano sa che il widget ha lavorato mentre era chiusa.
  Future<void> aggiornaGiorno(WidgetGiorno giorno);

  /// La giornata com'è stata pubblicata, o `null` se non c'è (l'app non è mai
  /// stata aperta, o il pacchetto è più vecchio di otto giorni).
  Future<WidgetGiorno?> leggiGiorno(DateTime giorno);

  /// Quando è arrivata l'ultima scrittura. L'app la confronta con quella che ha
  /// visto l'ultima volta: se è cambiata, i dati in memoria sono vecchi.
  Future<DateTime?> fattoIl();

  /// Riarma l'aggiornamento di **mezzanotte** per i prossimi giorni: alle 00:05
  /// il widget cambia giornata da solo, senza Flutter.
  Future<void> pianificaCambiGiorno(DateTime oggi);

  /// Registra la funzione che riceve i tocchi (la spunta di un todo), per
  /// quando l'app **non** è in esecuzione.
  Future<void> registraCallback(FutureOr<void> Function(Uri?) callback);

  /// L'URI con cui l'app è stata aperta dal widget, o `null`.
  Future<Uri?> uriDiAvvio();

  /// I tocchi che arrivano **mentre** l'app è aperta (di solito l'app si apre
  /// dal tocco, quindi è raro: c'è per non perdere il caso).
  Stream<Uri?> get tocchi;

  /// Scrive la scelta di un countdown (evento, titolo, data) sulle chiavi del
  /// widget e ridisegna: la scelta deve reggere anche con l'app chiusa.
  Future<void> salvaCountdown({
    required int widgetId,
    required String eventoId,
    required String titolo,
    required DateTime data,
  });
}
