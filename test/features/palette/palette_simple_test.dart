import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/core/database/schema.dart';
import 'package:planner/features/palette/domain/palette.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/theme/color_resolver.dart';
import 'package:sqlite3/sqlite3.dart';

/// I colori del modo **semplice** (fondo, superfici, testo): come si salvano,
/// cosa fanno al tema, e cosa succede se il dato e' storto.
///
/// Perche' contano: sono la risposta al difetto della recensione — «chi vuole
/// cambiare il colore dell'app non sa dove mettere le mani». Ma toccano il tema,
/// quindi vanno provati con i numeri (i colori letti), non a occhio.
///
/// L'**accento** non e' fra loro: il colore del tema e' quello scelto (il seed),
/// e un accento separato sarebbe un comando che non comanda. Il ruolo `primary`
/// di un tema salvato prima si ignora.
void main() {
  const tre = {
    'surface': '#f4efe6',
    'surfaceContainer': '#e6ded0',
    'onSurface': '#1b1a17',
  };

  group('modello', () {
    test('i colori semplici fanno il giro completo del database', () async {
      final db = DatabaseService();
      await db.init(dbPath: ':memory:');
      addTearDown(db.close);

      const palette = Palette(
        id: 'prova',
        name: 'Prova',
        seedHex: '#3f51b5',
        colors: ['#ff0000'],
        simpleColors: tre,
      );
      await PaletteController(db).save(palette);

      final riletta = PaletteController(db)..load();
      expect(riletta.byId('prova')?.simpleColors, tre);
    });

    test('un simple_json storto diventa «nessun colore», non un crash',
        () async {
      final raw = sqlite3.open(':memory:');
      addTearDown(raw.dispose);
      applySchema(raw);

      for (final storto in ['non-json', '[]', '{"surface": 42}', '{}']) {
        raw.execute(
          'INSERT OR REPLACE INTO palettes (id, name, seed_hex, colors_json, '
          "simple_json) VALUES ('x', 'X', '#000000', '[]', ?)",
          [storto],
        );
        final row = raw.select("SELECT * FROM palettes WHERE id = 'x'").first;
        expect(
          Palette.fromRow(row).simpleColors,
          isEmpty,
          reason: '«$storto» non è una mappa di colori: si ignora',
        );
      }
    });

    test('un ruolo che non esiste piu\' (l\'accento) viene ignorato', () {
      final raw = sqlite3.open(':memory:');
      addTearDown(raw.dispose);
      applySchema(raw);
      raw.execute(
        'INSERT INTO palettes (id, name, seed_hex, colors_json, simple_json) '
        "VALUES ('x', 'X', '#000000', '[]', ?)",
        [
          jsonEncode({
            'onSurface': '#123456',
            'primary': '#8b3a2f',
            'altro': '#ffffff',
          })
        ],
      );
      final row = raw.select("SELECT * FROM palettes WHERE id = 'x'").first;
      expect(Palette.fromRow(row).simpleColors, {'onSurface': '#123456'});
    });
  });

  group('tema', () {
    Palette con(Map<String, String> simple) => Palette(
          id: 'p',
          name: 'P',
          seedHex: '#3f51b5',
          colors: const [],
          simpleColors: simple,
        );

    test('i tre colori si applicano sopra lo schema', () {
      final scheme = ColorResolver.schemeFor(
        palette: con(tre),
        brightness: Brightness.light,
      );

      expect(scheme.surface, ColorResolver.hexToColor('#f4efe6'));
      expect(
        scheme.surfaceContainerHighest,
        ColorResolver.hexToColor('#e6ded0'),
      );
      expect(scheme.onSurface, ColorResolver.hexToColor('#1b1a17'));
      // E l'accento resta **il colore scelto**, anche con dei ruoli impostati:
      // un accento separato non esiste piu'.
      expect(scheme.primary, ColorResolver.hexToColor('#3f51b5'));
      expect(scheme.onPrimary, ColorResolver.onColor(scheme.primary));
    });

    test('tutto il resto resta quello del seed', () {
      final senza = ColorResolver.schemeFor(
        palette: con(const {}),
        brightness: Brightness.light,
      );
      final conTre = ColorResolver.schemeFor(
        palette: con(tre),
        brightness: Brightness.light,
      );

      // I ruoli che l'utente non tocca: contenitori, stati, superfici basse.
      expect(conTre.primaryContainer, senza.primaryContainer);
      expect(conTre.secondary, senza.secondary);
      expect(conTre.surfaceContainerHigh, senza.surfaceContainerHigh);
      expect(conTre.outline, senza.outline);
    });

    test('senza i colori semplici il tema e\' identico a prima', () {
      final senza = ColorResolver.schemeFor(
        palette: con(const {}),
        brightness: Brightness.light,
      );
      final soloSeed = ColorResolver.schemeFor(
        palette: const Palette(
          id: 'p',
          name: 'P',
          seedHex: '#3f51b5',
          colors: [],
        ),
        brightness: Brightness.light,
      );

      expect(senza.primary, soloSeed.primary);
      expect(senza.surface, soloSeed.surface);
    });
  });
}
