import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/palette/domain/presets.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';

/// La migrazione: un database dei temi vecchio diventa quello di oggi **senza**
/// che l'utente perda il tema.
///
/// La regola decisa: un tema che non c'è più si **sposta sul più vicino** di
/// tinta — non si ricade sul default, non si tiene un tema fantasma. Tutto
/// locale e senza outbox: i pronti non viaggiano e la rigenerazione è
/// deterministica.
void main() {
  late DatabaseService db;
  late PaletteController palettes;

  /// Uno stato vecchio, come poteva restare dopo la versione con l'armonia
  /// generata: pronti archiviati, «Rosso» coi colori generati, «Il mio colore»
  /// con la vecchia armonia, una palette personale, e un tema attivo che sta
  /// per essere archiviato.
  void sporcaIlDatabase() {
    void riga(
      String id,
      String name,
      String seed, {
      List<String> colors = const [],
      int isPreset = 1,
    }) {
      db.palettes.upsert({
        'id': id,
        'name': name,
        'seed_hex': seed,
        'colors_json': jsonEncode(colors),
        'simple_json': '{}',
        'is_preset': isPreset,
        'version': 3,
      });
    }

    riga('preset-classico', 'Classico', '#3F51B5', colors: ['#E57373']);
    riga('preset-inverno', 'Inverno', '#1565C0', colors: ['#64B5F6']);
    riga('preset-pastello', 'Pastello', '#C2185B', colors: ['#FF69B4']);
    riga('colore-grigio', 'Grigio', '#546E7A', colors: ['#78909C']);
    riga('colore-marrone', 'Marrone', '#6D4C41', colors: ['#8D6E63']);
    riga('colore-rosso', 'Rosso', '#D32F2F', colors: ['#E57373', '#F06292']);
    riga('mia', 'Mia', '#123456', colors: ['#654321'], isPreset: 0);
    riga(
      'il-mio-colore',
      'Il mio colore',
      '#2E7D5B',
      colors: ['#D32F2F', '#E57373'],
      isPreset: 0,
    );
    db.settings.set(AppSettingsController.activePaletteKey, 'preset-inverno');
  }

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    sporcaIlDatabase();
    palettes = PaletteController(db)..load();
  });

  tearDown(() => db.close());

  test('dopo l\'allineamento restano gli otto curati e il tuo colore', () {
    palettes.allineaPresets();

    final ids = [for (final palette in palettes.all) palette.id]..sort();
    final attesi = [
      for (final palette in presetColori) palette.id,
      PaletteController.myColorId,
    ]..sort();
    expect(ids, attesi, reason: 'i temi vecchi e le personali si archiviano');
  });

  test('il tema attivo archiviato si sposta sul più vicino', () {
    palettes.allineaPresets();
    // Inverno (#1565C0): la sua tinta è più vicina al Blu.
    expect(
      db.settings.get(AppSettingsController.activePaletteKey),
      'colore-blu',
    );
  });

  test('la mappa dei temi vecchi segue la tinta', () {
    // Regola: tinta più vicina, spareggio la luminosità. Nota: l'esempio del
    // piano «colore-grigio → Blu» era calcolato su semi provvisori — #546E7A è
    // un grigio con tinta turchese, quindi col seme vero il più vicino è il
    // Turchese.
    expect(coloreVicino('#1565C0').id, 'colore-blu', reason: 'inverno');
    expect(coloreVicino('#BF6B04').id, 'colore-arancione', reason: 'autunno');
    expect(coloreVicino('#2E7D5B').id, 'colore-verde', reason: 'primavera');
    expect(coloreVicino('#C2185B').id, 'colore-rosa', reason: 'pastello');
    expect(coloreVicino('#3F51B5').id, 'colore-blu', reason: 'classico');
    expect(coloreVicino('#6D4C41').id, 'colore-rosso', reason: 'marrone');
    expect(coloreVicino('#546E7A').id, 'colore-turchese', reason: 'grigio');
  });

  test('le definizioni di oggi riscrivono i colori generati vecchi', () {
    palettes.allineaPresets();
    expect(palettes.byId('colore-rosso')!.colors, [
      '#7E1B1B',
      '#D43535',
      '#E89292',
      '#A51D5C',
      '#E25A9A',
      '#F1D0DF',
      '#A55C1D',
      '#E29A5A',
    ]);
  });

  test('il tuo colore riprende la famiglia della sua tinta, senza outbox', () {
    final prima = palettes.byId(PaletteController.myColorId)!;
    palettes.allineaPresets();
    final dopo = palettes.byId(PaletteController.myColorId)!;

    expect(dopo.colors, famigliaVicina('#2E7D5B'));
    expect(dopo.colors, isNot(prima.colors),
        reason: 'la vecchia armonia generata se n\'è andata');
    expect(dopo.version, prima.version,
        reason: 'allineamento locale: il clock resta, niente sync');
    expect(db.outbox.pendingCount(), 0);
  });

  test('il secondo giro non scrive nulla', () {
    palettes.allineaPresets();
    final colori = {for (final p in palettes.all) p.id: p.colors};
    final clock = {for (final p in palettes.all) p.id: p.version};

    palettes.allineaPresets();
    expect({for (final p in palettes.all) p.id: p.colors}, colori);
    expect({for (final p in palettes.all) p.id: p.version}, clock);
    expect(db.outbox.pendingCount(), 0);
  });

  test('conColore: il colore scelto diventa tema e famiglia, su un tema solo',
      () async {
    // Come all'avvio: così la personale «mia» del database sporco viene
    // archiviata e del tuo resta solo «Il mio colore».
    palettes.allineaPresets();

    final nuova = palettes.conColore('#ff2d2d');
    expect(nuova.seedHex, '#ff2d2d');
    expect(nuova.colors, famigliaVicina('#ff2d2d'),
        reason: 'gli elementi seguono la famiglia curata più vicina');
    expect(nuova.colors, isNot(famigliaNeutro), reason: 'un rosso ha tinta');
    expect(nuova.simpleColors, isEmpty,
        reason: 'i ruoli scritti a mano si azzerano');
    expect(nuova.id, PaletteController.myColorId);

    await palettes.save(palettes.conColore('#ff2d2d'));
    await palettes.save(palettes.conColore('#808080'));
    expect(
      [for (final palette in palettes.custom) palette.id],
      [PaletteController.myColorId],
      reason: 'il tema tuo è uno solo: si riscrive',
    );
    expect(
      palettes.byId(PaletteController.myColorId)!.colors,
      famigliaNeutro,
      reason: 'un grigio senza tinta atterra sui neutri',
    );
  });
}
