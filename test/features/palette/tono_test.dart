import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/palette/domain/armonia.dart';
import 'package:planner/features/palette/domain/presets.dart';
import 'package:planner/features/palette/domain/tono.dart';
import 'package:planner/features/palette/palette_controller.dart';

void main() {
  test('daHsl riporta i primari al loro hex', () {
    expect(Armonia.daHsl(0, 1, 0.5), '#ff0000');
    expect(Armonia.daHsl(120, 1, 0.5), '#00ff00');
    expect(Armonia.daHsl(240, 1, 0.5), '#0000ff');
  });

  test('i toni mantengono la tinta e cambiano voce', () {
    final base = presetColori.first;
    final hb = Armonia.hsl(base.seedHex)!;

    final pastello = applicaTono(base, TonoTema.pastello);
    final hp = Armonia.hsl(pastello.seedHex)!;
    expect(hp[0], closeTo(hb[0], 0.01), reason: 'la tinta non gira');
    expect(hp[1], lessThan(hb[1]), reason: 'pastello è meno saturo');
    expect(hp[2], greaterThan(hb[2]), reason: 'pastello è più chiaro');

    final vivace = applicaTono(base, TonoTema.vivace);
    final hv = Armonia.hsl(vivace.seedHex)!;
    expect(hv[1], greaterThan(hb[1]), reason: 'vivace è più carico');

    final sobrio = applicaTono(base, TonoTema.sobrio);
    final hs = Armonia.hsl(sobrio.seedHex)!;
    expect(hs[1], lessThan(hb[1]), reason: 'sobrio è più discreto');
    expect(hs[2], lessThan(hb[2]), reason: 'sobrio è più profondo');
  });

  test('naturale lascia la palette com\'è', () {
    final base = presetColori.first;
    final uguale = applicaTono(base, TonoTema.naturale);
    expect(uguale.seedHex, base.seedHex);
    expect(uguale.colors, base.colors);
  });

  test('il tono è per-device: si salva e resolve lo applica', () async {
    final db = DatabaseService();
    await db.init(dbPath: ':memory:');
    addTearDown(db.close);

    final palettes = PaletteController(db)
      ..load()
      ..allineaPresets();
    final base = palettes.byId(defaultPaletteId)!;
    final atteso = applicaTono(base, TonoTema.pastello);

    palettes.setTono(TonoTema.pastello);
    expect(palettes.tono, TonoTema.pastello);
    expect(palettes.resolve(defaultPaletteId).seedHex, atteso.seedHex);
    expect(palettes.resolve(defaultPaletteId).colors, atteso.colors);
    // La palette salvata resta quella di partenza: il tono è una lente.
    expect(palettes.byId(defaultPaletteId)!.seedHex, base.seedHex);

    final riletto = PaletteController(db)..load();
    expect(riletto.tono, TonoTema.pastello);
  });
}
