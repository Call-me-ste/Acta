import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/palette/domain/presets.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/theme/color_resolver.dart';

/// I **colori curati**: ognuno è un **tema completo** — il seme fa il tema, la
/// famiglia a mano fa i colori degli elementi.
///
/// Perché si prova così: sono due cose che devono restare una sola palette. Un
/// colore pronto che cambia il tema ma **non** gli elementi (o viceversa) è il
/// difetto che si vede solo dopo aver scelto, quando l'app è colorata a metà.
void main() {
  late DatabaseService db;
  late PaletteController palettes;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    palettes = PaletteController(db)..load();
  });

  tearDown(() => db.close());

  group('gli otto colori curati', () {
    test('sono 8, con nomi e id distinti e deterministici', () {
      expect(presetColori, hasLength(8));
      expect(presetColori.map((palette) => palette.name).toSet(), hasLength(8));
      expect(presetColori.map((palette) => palette.id).toSet(), hasLength(8));
      for (final palette in presetColori) {
        expect(palette.id, startsWith('colore-'));
        expect(palette.isPreset, isTrue, reason: 'un pronto non si tocca');
        expect(palette.colors, hasLength(8));
      }

      // Gli id sono **deterministici**: due giri danno la stessa lista, quindi
      // ogni device li crea identici e il sync non deve trasportarli.
      expect(
        [for (final palette in presetTutti) palette.id],
        [for (final palette in presetTutti) palette.id],
      );
    });

    test('sono temi completi: il seme è il colore del tema', () {
      for (final palette in presetColori) {
        final scelto = ColorResolver.hexToColor(palette.seedHex)!;
        for (final brightness in Brightness.values) {
          final scheme = ColorResolver.schemeFor(
            palette: palette,
            brightness: brightness,
          );
          expect(
            scheme.primary,
            brightness == Brightness.light
                ? scelto
                : ColorResolver.darkVariant(scelto),
            reason: '${palette.name} ${brightness.name}',
          );
        }
      }
    });

    test('il database li semina tutti, una volta sola', () {
      palettes.allineaPresets();
      expect(palettes.all, hasLength(presetTutti.length));

      // Secondo giro: non raddoppia (id deterministici).
      palettes.allineaPresets();
      expect(palettes.all, hasLength(presetTutti.length));
      expect(palettes.byId('colore-rosso')?.name, 'Rosso');
    });

    test('senza tema valido si ricade sul Blu', () {
      expect(palettes.resolve('colore-che-non-esiste').id, defaultPaletteId);
      expect(palettes.resolve(null).id, defaultPaletteId);
    });
  });
}
