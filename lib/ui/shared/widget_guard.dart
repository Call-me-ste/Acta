import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/categories/category_controller.dart';
import '../../features/categories/domain/category.dart';
import '../../features/events/domain/event_occurrence.dart';
import '../../features/events/event_provider.dart';
import '../../features/palette/palette_controller.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/todos/todo_recurrence.dart';
import '../../features/todos/todo_windows.dart';
import '../../features/widgets/home_widget_bridge.dart';
import '../../features/widgets/widget_actions.dart';
import '../../features/widgets/widget_bridge.dart';
import '../../features/widgets/widget_mese_snapshot.dart';
import '../../features/widgets/widget_snapshot.dart';
import '../../theme/app_theme.dart';
import '../../theme/color_resolver.dart';
import 'widget_open.dart';
import 'widget_theme.dart';

/// Chi tiene i widget **allineati ai dati**: quando l'app si apre, quando
/// qualcosa cambia, e quando il widget ha spuntato qualcosa mentre l'app era
/// chiusa.
///
/// Un widget e non del codice dentro `main.dart`, come `ReminderGuard` e
/// `BackupGuard`: così si può provare. E perché quello che fa non si vede — un
/// widget fermo sulla giornata di ieri si scopre il giorno dopo.
///
/// **Cosa non fa:** non sveglia l'app per aggiornare i widget. Il pacchetto
/// porta otto giorni, e il sistema ridisegna il widget da solo (ogni mezz'ora e
/// a mezzanotte, con l'allarme che `pianificaCambiGiorno` riarma): l'app può
/// restare chiusa per una settimana e il widget resta giusto.
class WidgetGuard extends StatefulWidget {
  const WidgetGuard({super.key, required this.child, this.ponte});

  final Widget child;

  /// Il ponte verso la schermata home. Si passa da fuori per i test: senza,
  /// ogni prova sui widget vorrebbe un telefono collegato.
  final WidgetBridge? ponte;

  @override
  State<WidgetGuard> createState() => _WidgetGuardState();
}

class _WidgetGuardState extends State<WidgetGuard> with WidgetsBindingObserver {
  WidgetBridge get _ponte => widget.ponte ?? _pontiDiSistema;

  /// Il ponte vero: uno solo per tutta l'app (il plugin tiene i dati in un posto
  /// solo, e due istanze non avrebbero senso).
  static const WidgetBridge _pontiDiSistema = HomeWidgetBridge();

  /// L'ultima scrittura che **sappiamo** già contata: quella che abbiamo scritto
  /// noi, o quella che abbiamo appena letto. Serve a distinguere «il widget ha
  /// lavorato mentre eravamo chiusi» da «abbiamo appena scritto noi».
  DateTime? _scritturaVista;

  /// Il rinvio del giro di scrittura: tre modifiche di fila fanno un pacchetto
  /// solo. Due secondi, non millisecondi: qui non si sta aspettando
  /// un'animazione, si sta aspettando che chi scrive abbia finito (l'architettura
  /// vieta le durate in millisecondi fuori dai token proprio per non confondere
  /// le due cose).
  Timer? _rinvio;

  bool _pronto = false;
  StreamSubscription<Uri?>? _tocchi;

  /// Le sorgenti che, cambiando, cambiano il pacchetto. Si tengono **qui** e non
  /// si rileggono dal `context` in `dispose`: a quel punto l'elemento è staccato e
  /// cercare un antenato è un'asserzione («Looking up a deactivated widget's
  /// ancestor is unsafe» — l'ha trovata il test della guardia). E servono anche
  /// dopo un `await`, dove usare il `context` è un altro modo di sbagliare.
  EventProvider? _eventi;
  TodoProvider? _todo;
  PaletteController? _palette;
  CategoryController? _categorie;
  AppSettingsController? _impostazioni;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _avvia());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pronto) return;
    _pronto = true;

    // Chi, cambiando, cambia quello che il widget mostra: i dati, la palette (i
    // colori degli elementi) e le categorie (le emoji).
    _eventi = context.read<EventProvider>()..addListener(_qualcosaECambiato);
    _todo = context.read<TodoProvider>()..addListener(_qualcosaECambiato);
    _palette = context.read<PaletteController>()
      ..addListener(_qualcosaECambiato);
    _categorie = context.read<CategoryController>()
      ..addListener(_qualcosaECambiato);
    _impostazioni = context.read<AppSettingsController>();
  }

  Future<void> _avvia() async {
    if (!mounted) return;

    // Il callback dei tocchi **prima** di tutto: se il widget viene toccato
    // mentre l'app parte, il plugin deve sapere chi chiamare.
    await _ponte.registraCallback(callbackDelWidget);
    _scritturaVista = await _ponte.fattoIl();
    if (!mounted) return;
    _tocchi = _ponte.tocchi.listen((uri) {
      if (!mounted) return;
      apriDaWidget(
        context,
        uri,
        ponte: _ponte,
        eventi: _eventi,
        todos: _todo,
      );
    });

    // L'avvio da widget va letto **prima** di pubblicare: se è un giorno, la
    // richiesta deve essere in casa prima che il guscio chieda gli scaduti.
    final avvio = await _ponte.uriDiAvvio();
    if (!mounted) return;
    apriDaWidget(
      context,
      avvio,
      ponte: _ponte,
      eventi: _eventi,
      todos: _todo,
    );

    await _pubblica();
  }

  /// Una scrittura qualsiasi: si ripubblica, **fra poco**.
  void _qualcosaECambiato() {
    if (!mounted) return;
    _rinvio?.cancel();
    _rinvio = Timer(const Duration(seconds: 2), _pubblica);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(_allinea());
  }

  /// Tornando in primo piano: se il widget ha scritto mentre l'app era chiusa, i
  /// dati in memoria sono **vecchi** (la spunta è nel database, non nella lista),
  /// quindi si rileggono e si ripubblica.
  Future<void> _allinea() async {
    final quando = await _ponte.fattoIl();
    if (quando == _scritturaVista) return;

    _scritturaVista = quando;
    if (quando != null) {
      // Il widget ha scritto: la lista in memoria è vecchia.
      _eventi?.reload();
      _todo?.reload();
    }
    await _pubblica();
  }

  /// Costruisce il pacchetto e lo consegna alla schermata home.
  Future<void> _pubblica() async {
    if (!mounted) return;

    final adesso = DateTime.now();
    final eventi = _eventi;
    final todo = _todo;
    final impostazioni = _impostazioni;
    final paletteScelta = _palette;
    if (eventi == null ||
        todo == null ||
        impostazioni == null ||
        paletteScelta == null) {
      return;
    }

    final palette = paletteScelta.resolve(impostazioni.activePaletteId);
    final emoji = {
      for (final categoria in _categorie?.all ?? const <ItemCategory>[])
        categoria.id: categoria.emoji,
    };
    final priorita = impostazioni.priorityColors;

    // I colori degli elementi sono gli stessi per le righe del giorno e per le
    // anteprime del mese: una funzione sola, due pacchetti.
    String coloreEvento(EventOccurrence occorrenza, Brightness luminosita) =>
        ColorResolver.colorToHex(
          ColorResolver.elementColor(
            palette: palette,
            brightness: luminosita,
            index: occorrenza.colorIndex,
            customHex: occorrenza.event.colorHex,
          ),
        );

    // Gli schemi dei due temi si costruiscono **una volta** e servono a tre cose:
    // il colore degli elementi, il ripiego, e il tema che va al widget.
    final schemeChiaro = AppTheme.schemeFor(palette, Brightness.light);
    final schemeScuro = AppTheme.schemeFor(palette, Brightness.dark);
    Color ripiego(Brightness intensita) =>
        (intensita == Brightness.dark ? schemeScuro : schemeChiaro).primary;

    final materiale = MaterialeDelWidget(
      adesso: adesso,
      eventiDelGiorno: (giorno) => eventi.occurrencesForDate(giorno),
      todoDelGiorno: todo.todosForDate,
      todoFatto: todo.isDoneOn,
      coloreEvento: (occorrenza, luminosita) => ColorResolver.colorToHex(
        ColorResolver.elementColor(
          palette: palette,
          brightness: luminosita,
          index: occorrenza.colorIndex,
          customHex: occorrenza.event.colorHex,
        ),
      ),
      coloreTodo: (elemento, luminosita) => coloreTodoDelWidget(
        elemento,
        palette,
        intensita: luminosita,
        priorita: priorita,
        ripiego: ripiego(luminosita),
      ),
      emoji: (categorie) =>
          categorie.isEmpty ? '' : (emoji[categorie.first] ?? ''),
      etichettaDelGiorno: (giorno) => etichettaDelGiorno(giorno, adesso),
    );

    await _ponte.pubblica(
      giorni: pacchettoDelWidget(oggi: adesso, materiale: materiale),
      mesi: pacchettoDeiMesi(
        oggi: adesso,
        materiale: MaterialeDelMese(
          adesso: adesso,
          // Una passata per mese (griglia e mesi adiacenti compresi), non una
          // domanda per cella.
          eventiIntervallo: eventi.occurrencesBetween,
          coloreEvento: coloreEvento,
          etichettaDelMese: etichettaDelMese,
        ),
      ),
      tema: temaDelWidget(palette),
      adesso: adesso,
    );
    await _ponte.pianificaCambiGiorno(adesso);
    _scritturaVista = await _ponte.fattoIl();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rinvio?.cancel();
    unawaited(_tocchi?.cancel());
    _eventi?.removeListener(_qualcosaECambiato);
    _todo?.removeListener(_qualcosaECambiato);
    _palette?.removeListener(_qualcosaECambiato);
    _categorie?.removeListener(_qualcosaECambiato);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
