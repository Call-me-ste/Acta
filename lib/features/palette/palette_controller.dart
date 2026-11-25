import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_service.dart';
import '../settings/app_settings_controller.dart';
import 'domain/palette.dart';
import 'domain/presets.dart';
import 'domain/tono.dart';

/// La libreria delle palette: i preset e quelle personalizzate.
///
/// I preset nascono **in locale** e senza passare dall'outbox: gli id sono
/// deterministici, quindi ogni device li genera identici al primo avvio. Se li
/// spedissimo, il primo avvio di ogni dispositivo accoderebbe sei operazioni
/// inutili e i due si riscriverebbero le stesse righe a vicenda.
/// Una palette personalizzata, invece, è una scrittura come le altre: passa
/// dall'outbox e viaggia.
class PaletteController extends ChangeNotifier {
  PaletteController(this._db);

  final DatabaseService _db;
  static const _uuid = Uuid();
  static const String _entity = 'palette';
  static const String _toneKey = 'toneTema';

  List<Palette> _palettes = [];
  TonoTema _tono = TonoTema.naturale;

  /// Il tono scelto per **questo device**: non viaggia nel sync, come il tema
  /// chiaro/scuro. È una lente sopra il colore attivo, non un'altra palette.
  TonoTema get tono => _tono;

  List<Palette> get all => _palettes;

  List<Palette> get custom =>
      _palettes.where((palette) => !palette.isPreset).toList();

  Palette? byId(String id) {
    for (final palette in _palettes) {
      if (palette.id == id) return palette;
    }
    return null;
  }

  /// La palette attiva. Non fallisce **mai**: un id sconosciuto (palette
  /// cancellata su un altro device, database nuovo, backup vecchio) ricade sul
  /// preset di default invece di lasciare l'app senza tema.
  Palette resolve(String? id) => applicaTono(_base(id), _tono);

  Palette _base(String? id) {
    return byId(id ?? '') ??
        byId(defaultPaletteId) ??
        presetColori.firstWhere((palette) => palette.id == defaultPaletteId);
  }

  void setTono(TonoTema tono) {
    if (tono == _tono) return;
    _tono = tono;
    _db.settings.set(_toneKey, tono.name);
    notifyListeners();
  }

  void load() {
    _tono = TonoTema.daNome(_db.settings.get(_toneKey));
    _palettes = _db.palettes.all().map(Palette.fromRow).toList();
    notifyListeners();
  }

  /// Allinea i pronti alle definizioni di oggi e archivia il resto.
  ///
  /// In un giro solo:
  /// - crea o aggiorna gli otto colori curati (le tabelle cambiano: le righe
  ///   vecchie avevano i colori **generati**, e vanno rimpiazzate);
  /// - **archivia** ogni riga che non è più fra le definizioni — pronti
  ///   vecchi, stagionali, personali superflue: del tuo resta solo «Il mio
  ///   colore»;
  /// - se il tema attivo punta a un archiviato lo **sposta sul più vicino** di
  ///   tinta: l'utente non si vede cambiare il tema sotto il naso;
  /// - rigenera i colori di «Il mio colore» dalla sua famiglia.
  ///
  /// Tutto **in locale e senza outbox**: gli id dei pronti sono deterministici
  /// (non viaggiano) e la rigenerazione è deterministica, quindi ogni device
  /// arriva agli stessi valori senza parlarsi. Idempotente: al secondo giro non
  /// scrive nulla.
  void allineaPresets() {
    final attese = {for (final palette in presetTutti) palette.id};
    final archiviati = <String, String>{
      for (final palette in _palettes)
        if (!attese.contains(palette.id) && palette.id != myColorId)
          palette.id: palette.seedHex,
    };

    final daScrivere = [
      for (final palette in presetTutti)
        if (!_stessoContenuto(byId(palette.id), palette)) palette,
    ];

    final mio = byId(myColorId);
    Palette? mioDaScrivere;
    if (mio != null) {
      final aggiornato = mio.copyWith(colors: famigliaVicina(mio.seedHex));
      if (!_stessoContenuto(mio, aggiornato)) mioDaScrivere = aggiornato;
    }

    if (daScrivere.isEmpty && archiviati.isEmpty && mioDaScrivere == null) {
      return;
    }

    _db.runInTransaction(() {
      for (final palette in daScrivere) {
        _db.palettes.upsert(palette.toParams());
      }
      for (final id in archiviati.keys) {
        _db.palettes.delete(id);
      }
      if (mioDaScrivere != null) {
        // Locale e senza outbox: la rigenerazione è deterministica, ogni
        // device ricalcola gli stessi hex dallo stesso seme.
        _db.palettes.upsert(mioDaScrivere.toParams());
      }
    });

    final attivo = _db.settings.get(AppSettingsController.activePaletteKey);
    if (attivo != null && archiviati.containsKey(attivo)) {
      _db.settings.set(
        AppSettingsController.activePaletteKey,
        coloreVicino(archiviati[attivo]!).id,
      );
    }

    load();
  }

  /// Due palette sono la stessa cosa per l'allineamento: nome, seme, colori e
  /// ruoli. Il clock (versione, data) **non** conta: quello lo fa `save`.
  static bool _stessoContenuto(Palette? a, Palette b) {
    if (a == null) return false;
    final pa = a.toParams();
    final pb = b.toParams();
    return pa['name'] == pb['name'] &&
        pa['seed_hex'] == pb['seed_hex'] &&
        pa['colors_json'] == pb['colors_json'] &&
        pa['simple_json'] == pb['simple_json'] &&
        pa['is_preset'] == pb['is_preset'];
  }

  /// Salva una palette personalizzata (o una modifica). Avanza il clock, come
  /// ogni altra scrittura: è quello che il sync confronta.
  Future<void> save(Palette palette) async {
    final next = palette.copyWith(
      version: palette.version + 1,
      updatedAt: DateTime.now(),
    );

    _db.runInTransaction(() {
      _db.palettes.upsert(next.toParams());
      _db.outbox.enqueue(
        operationId: _uuid.v4(),
        entity: _entity,
        entityId: next.id,
        operation: 'upsert',
        version: next.version,
        updatedAt: next.updatedAt!.millisecondsSinceEpoch,
        payload: next.toParams(),
      );
    });
    load();
  }

  /// L'id e il nome del **tema tuo**: e' uno solo, sempre lo stesso. Scegliendo
  /// un colore dalla ruota si **riscrive** lui, invece di accumulare una copia a
  /// ogni scelta (era il modo per ritrovarsi dieci «Colore personale»).
  static const String myColorId = 'il-mio-colore';
  static const String myColorName = 'Il mio colore';

  /// La palette che nasce da un **colore scelto a mano** (la ruota): il colore
  /// diventa il tema, e i colori degli elementi sono la sua **famiglia
  /// curata** più vicina — cosi' scegliere un colore cambia anche gli
  /// elementi, non solo l'accento.
  ///
  /// I ruoli scritti a mano si azzerano: altrimenti vincerebbero loro e il colore
  /// appena scelto non si vedrebbe.
  Palette conColore(String hex) {
    final mio = byId(myColorId) ??
        const Palette(
          id: myColorId,
          name: myColorName,
          seedHex: '#3f51b5',
          colors: [],
        );
    return mio.copyWith(
      seedHex: hex,
      colors: famigliaVicina(hex),
      simpleColors: const {},
      updatedAt: DateTime.now(),
    );
  }
}
