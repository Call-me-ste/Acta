/// Il **contratto** fra Dart e il renderer Kotlin dei widget: chiavi, URI, tetti,
/// nomi dei provider e le frasi che si leggono sul widget.
///
/// Sta in un posto solo perché i due lati non possono leggersi a vicenda: se una
/// chiave cambia qui, va cambiata anche in
/// `android/app/src/main/kotlin/com/callmeste/planner/widget/WidgetPayload.kt`
/// (il commento in testa a quel file rimanda qui). I test controllano la forma del
/// JSON, quindi una divergenza si vede prima del telefono.
///
/// **I nomi del plugin sono presi dai suoi sorgenti**, non dalla documentazione
/// online (`home_widget-0.10.0`, in `pub-cache`, la cui doc descrive soprattutto
/// la via Glance che qui non si usa):
///
/// * `es.antonborri.home_widget.HomeWidgetProvider` — la classe base del
///   provider, con `onUpdate(context, appWidgetManager, ids, widgetData:
///   SharedPreferences)`: è da `widgetData` che il Kotlin legge il JSON;
/// * `...HomeWidgetIntent.HomeWidgetBackgroundIntent.getBroadcast(context, uri)`
///   — la spunta che gira **in background**, senza aprire l'app (il receiver
///   passa da `HomeWidgetBackgroundWorker`, cioè WorkManager: affidabile anche
///   con l'app morta);
/// * `...HomeWidgetIntent.HomeWidgetLaunchIntent.getActivity(context,
///   MainActivity::class.java, uri)` — il tocco che **apre l'app** su un elemento;
/// * `HomeWidget.scheduleWidgetUpdates([...])` con il receiver
///   `HomeWidgetScheduledUpdateReceiver` (il plugin lo riarma su `BOOT_COMPLETED`,
///   su `MY_PACKAGE_REPLACED` e sul cambio del permesso degli allarmi esatti):
///   è l'aggiornamento di mezzanotte, e non c'è una riga nostra di `AlarmManager`.
library;

/// Quanti giorni porta il pacchetto: **oggi più i sette dopo**.
///
/// È quello che rende i widget corretti anche se l'app non si apre per giorni:
/// il Kotlin sceglie la chiave del giorno che serve senza chiedere niente a
/// Flutter. Otto giorni sono ~20 KB di preferenze.
const int giorniNelPacchetto = 8;

/// Quante righe di un giorno stanno nel pacchetto. I **conteggi** veri viaggiano
/// a parte, così «+N altri» non mente quando il giorno è pieno.
const int righeNelPacchetto = 12;

/// Quanti mesi porta il pacchetto **mensile**: quello corrente e i due adiacenti.
///
/// Tre perché il widget si può guardare avanti e indietro di un mese senza
/// aprire l'app; oltre, il widget lo dice e apre l'app. Ogni mese sono ~42
/// giorni con poche anteprime: resta qualche decina di KB di preferenze.
const int mesiNellaFinestra = 3;

/// Quante anteprime di evento stanno in una cella del mese. Le altre si contano
/// («+N»): il numero vero è `eventi` nel giorno del pacchetto.
const int anteprimeNelMese = 2;

/// A che ora si ridisegnano i widget al cambio di giorno: **00:05**, cinque
/// minuti dopo la mezzanotte (l'allarme esatto può arrivare con qualche secondo
/// di ritardo, e i minuti non si vedono).
const int minutiDelCambioGiorno = 5;

/// Le chiavi nello spazio di `home_widget` (`/`, `\`, `..` e spazi sono vietati
/// dal plugin: quelle di sotto sono semplici).
const String chiaveTema = 'widget_tema';
const String chiaveUltimoGiorno = 'widget_ultimo_giorno';

/// Quando l'**ultima** scrittura è arrivata (millisecondi). Serve alla guardia:
/// se il widget ha spuntato qualcosa mentre l'app era chiusa, l'app lo scopre da
/// qui e rilegge i dati invece di mostrare quelli di prima.
const String chiaveFattoIl = 'widget_fatto_il';

/// La chiave del giorno: `widget_giorno_2026-09-24`.
String chiaveGiorno(DateTime giorno) => 'widget_giorno_${dataIso(giorno)}';

/// `2026-09`: la forma dell'anno-mese nelle chiavi del pacchetto mensile.
String annoMeseIso(DateTime mese) => '${mese.year.toString().padLeft(4, '0')}-'
    '${mese.month.toString().padLeft(2, '0')}';

/// La chiave del mese: `widget_mese_2026-09`.
String chiaveMese(DateTime mese) => 'widget_mese_${annoMeseIso(mese)}';

/// L'**indice** dei mesi pubblicati (`2026-08,2026-09,2026-10`).
///
/// Serve al Kotlin per non servire una chiave rimasta da un giro vecchio: senza
/// indice, un mese scritto ieri e mai riscritto sembrerebbe attuale. È la
/// finestra, non un dato del calendario.
const String chiaveMesiPubblicati = 'widget_mesi_pubblicati';

/// I tre provider dichiarati nel manifest, in coppia.
///
/// `nome` è il nome **semplice** (quello che serve a iOS); `qualificato` è il nome
/// **pieno di classe**, e per Android è quello che ci vuole: il plugin fa
/// `"${packageName}.${className}"`, quindi passandogli il nome già qualificato
/// cercava `com.callmeste.planner.com.callmeste.planner.widget.Oggi…` e finiva in
/// `PlatformException(-3)` — l'ha trovato la prova sul telefono il 24/09, e
/// valeva anche per l'allarme di mezzanotte.
const List<({String nome, String qualificato})> providerDeiWidget = [
  (
    nome: 'MeseWidgetProvider',
    qualificato: 'com.callmeste.planner.widget.MeseWidgetProvider'
  ),
  (
    nome: 'OggiWidgetProvider',
    qualificato: 'com.callmeste.planner.widget.OggiWidgetProvider'
  ),
  (
    nome: 'TodoWidgetProvider',
    qualificato: 'com.callmeste.planner.widget.TodoWidgetProvider'
  ),
  (
    nome: 'MeseGrandeWidgetProvider',
    qualificato: 'com.callmeste.planner.widget.MeseGrandeWidgetProvider'
  ),
  (
    nome: 'MeseCompattoWidgetProvider',
    qualificato: 'com.callmeste.planner.widget.MeseCompattoWidgetProvider'
  ),
  (
    nome: 'EventiWidgetProvider',
    qualificato: 'com.callmeste.planner.widget.EventiWidgetProvider'
  ),
  (
    nome: 'CountdownWidgetProvider',
    qualificato: 'com.callmeste.planner.widget.CountdownWidgetProvider'
  ),
];

/// Le frasi degli stati vuoti: viaggiano **nel pacchetto** (non sono nel Kotlin)
/// perché la voce dell'app è una cosa sola e si prova in Dart.
const String testoVuoto = 'Niente in programma per oggi.';
const String testoTuttoFatto = 'Nient\'altro in programma per oggi.';
const String testoOggi = 'Oggi';
const String testoTuttoIlGiorno = 'tutto il giorno';

/// Quando il pacchetto non copre più oggi (l'app non si apre da più di otto
/// giorni): la dice il **Kotlin**, perché in quel caso non c'è nessun pacchetto da
/// leggere. Deve restare uguale a `res/values/strings.xml`.
const String testoAggiorna = 'Apri il Planner per aggiornare.';

/// Quando il mese che il widget sta guardando non è nella finestra pubblicata
/// (l'app non si apre da più di un mese, o si è arrivati col tasto della
/// freccia fino in fondo): il widget non inventa giorni, lo dice e apre l'app.
/// Deve restare uguale a `res/values/strings.xml`.
const String testoFuoriFinestra = 'Apri Planner per gli altri mesi.';

/// La chiave con cui la build **di test** fa credere ai widget che oggi sia un
/// altro giorno: è la prova del cambio di giornata senza aspettare mezzanotte
/// (`lib/dev/widget_prova.dart`). Nella build ufficiale non la scrive nessuno, e
/// il Kotlin la ignora se non è una data.
const String chiaveOggiDiProva = 'widget_oggi_di_prova';

/// `2026-09-24`: la forma della data nelle chiavi e negli URI.
String dataIso(DateTime giorno) => '${giorno.year.toString().padLeft(4, '0')}-'
    '${giorno.month.toString().padLeft(2, '0')}-'
    '${giorno.day.toString().padLeft(2, '0')}';

/// Lo schema degli URI dei tocchi. `planner://` non è un deep link pubblico: è
/// solo il modo in cui il widget dice all'app **cosa** è stato toccato.
const String schemaWidget = 'planner';

/// La spunta di un todo: la riceve il callback di sfondo, che scrive e ridisegna.
Uri uriSpunta({required String id, required DateTime giorno}) => Uri(
      scheme: schemaWidget,
      host: 'spunta',
      queryParameters: {'tipo': 'todo', 'id': id, 'giorno': dataIso(giorno)},
    );

/// Apre l'app **su un elemento** (il form dell'evento o del todo).
Uri uriApriElemento({
  required String tipo,
  required String id,
  required DateTime giorno,
}) =>
    Uri(
      scheme: schemaWidget,
      host: 'apri',
      queryParameters: {'tipo': tipo, 'id': id, 'giorno': dataIso(giorno)},
    );

/// Apre l'app sulla giornata (l'intestazione del widget, il «+N altri»).
Uri uriApriGiorno(DateTime giorno) => Uri(
      scheme: schemaWidget,
      host: 'apri',
      queryParameters: {'giorno': dataIso(giorno)},
    );

/// Le chiavi della **scelta del countdown**, per widget id.
String chiaveCountdownEvento(int widgetId) =>
    'widget_countdown_evento_$widgetId';
String chiaveCountdownTitolo(int widgetId) =>
    'widget_countdown_titolo_$widgetId';
String chiaveCountdownData(int widgetId) => 'widget_countdown_data_$widgetId';

/// Il tocco sul countdown: apre il selettore dell'evento per quel widget.
Uri uriCountdown(int widgetId) => Uri(
      scheme: schemaWidget,
      host: 'countdown',
      queryParameters: {'widget': '$widgetId'},
    );

/// Cosa dice un URI toccato sul widget.
typedef ToccaDelWidget = ({
  String azione,
  String? tipo,
  String? id,
  DateTime? giorno,
  int? widget,
});

/// Legge l'URI di un tocco: `null` se non è roba nostra (o se è scritto male).
///
/// Una funzione sola per il callback di sfondo e per l'apertura dell'app: i due
/// percorsi ricevono lo stesso URI e non devono interpretarlo ognuno a modo suo.
ToccaDelWidget? leggiToccaDelWidget(Uri? uri) {
  if (uri == null || uri.scheme != schemaWidget) return null;
  final azione = uri.host;
  if (azione != 'spunta' &&
      azione != 'apri' &&
      azione != 'nuovo' &&
      azione != 'countdown') {
    return null;
  }

  final quando = uri.queryParameters['giorno'];
  return (
    azione: azione,
    tipo: uri.queryParameters['tipo'],
    id: uri.queryParameters['id'],
    giorno: quando == null ? null : _dataDaIso(quando),
    widget: int.tryParse(uri.queryParameters['widget'] ?? ''),
  );
}

/// `null` se la stringa non è una data `AAAA-MM-GG`: un URI sbagliato non deve
/// far saltare il callback di sfondo (che gira senza nessuno che guardi).
DateTime? _dataDaIso(String valore) => DateTime.tryParse(valore);
