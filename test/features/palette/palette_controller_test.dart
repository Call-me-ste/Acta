import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/palette/domain/palette.dart';
import 'package:planner/features/palette/domain/presets.dart';
import 'package:planner/features/palette/palette_controller.dart';

void main() {
  late DatabaseService db;
  late PaletteController palettes;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    palettes = PaletteController(db)
      ..load()
      ..allineaPresets();
  });

  tearDown(() => db.close());

  test('i preset nascono al primo avvio', () {
    // Un solo gruppo: gli otto colori curati, pronti che non si toccano.
    expect(palettes.all.length, presetTutti.length);
    expect(presetTutti.length, 8);
    expect(palettes.custom, isEmpty);
  });

  test('riseedare non duplica niente', () {
    palettes.allineaPresets();
    palettes.allineaPresets();
    expect(palettes.all.length, presetTutti.length);
  });

  test('i preset NON finiscono nell\'outbox: gli id sono deterministici', () {
    // Se li spedissimo, il primo avvio di ogni device accoderebbe sei operazioni
    // inutili e i due si riscriverebbero le stesse righe a vicenda.
    expect(db.outbox.pendingCount(), 0);
  });

  test('la palette attiva ricade sul default se l\'id non esiste', () {
    expect(palettes.resolve('preset-che-non-esiste').id, defaultPaletteId);
    expect(palettes.resolve(null).id, defaultPaletteId);
    expect(palettes.resolve('colore-rosa').id, 'colore-rosa');
  });

  test('una palette personale si crea, si salva, e il preset resta intatto',
      () async {
    const mia = Palette(
      id: 'mia',
      name: 'Mia',
      seedHex: '#00897B',
      colors: ['#81C784'],
    );
    await palettes.save(mia);

    expect(palettes.custom.length, 1);
    // Il preset originale resta intatto: i pronti non si toccano.
    expect(palettes.byId('colore-rosa')!.isPreset, isTrue);
  });

  test('salvare una palette avanza il clock e accoda il sync', () async {
    const mia = Palette(
      id: 'mia',
      name: 'Mia',
      seedHex: '#3F51B5',
      colors: ['#81C784'],
    );
    await palettes.save(mia);
    // Il primo `save` di una palette nuova scrive la versione 1: il modello nasce
    // con version 1 e `save` la fa avanzare a 2 — ma qui la palette nasce da
    // `const mia` (version 1) e la riga salvata è la 2.
    final copy = palettes.byId('mia')!;
    expect(copy.version, 2, reason: '1 alla creazione, 2 al salvataggio');

    await palettes.save(copy.copyWith(name: 'Mia due', seedHex: '#00897B'));

    final saved = palettes.byId('mia')!;
    expect(saved.name, 'Mia due');
    expect(saved.seedHex, '#00897B');
    // Il clock avanza a ogni scrittura: 1 alla creazione, 2 al primo salvataggio,
    // 3 a questo.
    expect(saved.version, 3);
    expect(db.outbox.pendingCount(), 2,
        reason: 'una per la creazione e una per la modifica');
  });

  test('i preset non si possono cancellare: il comando non esiste', () {
    // La pagina avanzata (che li cancellava) non esiste piu': il tema dell'utente
    // e' uno solo e si riscrive, quindi non c'e' niente da eliminare.
    expect(palettes.byId('colore-blu'), isNotNull);
  });

  test('una palette illeggibile non fa fallire il caricamento', () {
    db.palettes.upsert({
      'id': 'rotta',
      'name': 'Rotta',
      'seed_hex': '#123456',
      'colors_json': 'non-json',
      'is_preset': 0,
      'version': 1,
    });

    palettes.load();
    expect(palettes.byId('rotta')!.colors, isEmpty);
    // Senza colori si ricade sul seed: il tema c'è comunque.
    expect(palettes.byId('rotta')!.colorAt(0), '#123456');
  });
}
