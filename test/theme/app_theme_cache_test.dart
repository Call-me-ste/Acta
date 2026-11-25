import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/palette/domain/palette.dart';
import 'package:planner/theme/app_theme.dart';

/// La memoria di schemi e temi.
///
/// Perché conta: `ColorScheme.fromSeed` costa **2,15 ms** (misurato sul telefono,
/// `docs/fluidita.md`) e i punti che disegnano un'anteprima lo chiedono a ogni
/// build — il foglio dei colori, la pagina avanzata, e la shell (che costruisce
/// chiaro e scuro a ogni build). Qui si prova l'unica cosa che conta: la seconda
/// volta **non** si ricostruisce, e la memoria non restituisce il tema di un'altra
/// palette.
void main() {
  Palette palette(
    String id,
    String seed, {
    Map<String, String> simple = const {},
  }) =>
      Palette(
        id: id,
        name: id,
        seedHex: seed,
        colors: const ['#ff0000'],
        simpleColors: simple,
      );

  test('lo stesso tema torna lo stesso oggetto, in chiaro e in scuro', () {
    final p = palette('p', '#3f51b5');

    expect(
      identical(
        AppTheme.tema(p, Brightness.light),
        AppTheme.tema(p, Brightness.light),
      ),
      isTrue,
    );
    expect(
      identical(
        AppTheme.schemeFor(p, Brightness.light),
        AppTheme.schemeFor(p, Brightness.light),
      ),
      isTrue,
    );
    // Chiaro e scuro restano due cose diverse.
    expect(
      identical(
        AppTheme.tema(p, Brightness.light),
        AppTheme.tema(p, Brightness.dark),
      ),
      isFalse,
    );
  });

  test('una palette modificata non restituisce il tema di prima', () {
    final prima = palette('p', '#3f51b5');
    final dopo = palette('p', '#c2185b');
    final temaPrima = AppTheme.tema(prima, Brightness.light);

    final temaDopo = AppTheme.tema(dopo, Brightness.light);

    expect(identical(temaPrima, temaDopo), isFalse);
    expect(
      temaDopo.colorScheme.primary,
      isNot(temaPrima.colorScheme.primary),
    );
  });

  test('anche i colori semplici contano nella chiave', () {
    final senza = palette('p', '#3f51b5');
    final con = palette('p', '#3f51b5', simple: {'onSurface': '#8b3a2f'});

    expect(
      identical(
        AppTheme.tema(senza, Brightness.light),
        AppTheme.tema(con, Brightness.light),
      ),
      isFalse,
      reason: 'stesso seed, ma i colori semplici sono diversi',
    );
  });

  test('una palette senza accento non porta l\'accento di un\'altra', () {
    // Il ruolo `primary` non esiste piu': la chiave non lo contiene, quindi due
    // palette con lo stesso seed e un accento di troppo sono lo **stesso** tema
    // (e il tema e' quello del seed).
    final conAccento = palette('p', '#3f51b5', simple: {'primary': '#8b3a2f'});
    final solo = palette('p', '#3f51b5');

    expect(
      identical(
        AppTheme.tema(conAccento, Brightness.light),
        AppTheme.tema(solo, Brightness.light),
      ),
      isTrue,
    );
    expect(
      AppTheme.tema(solo, Brightness.light).colorScheme.primary,
      const Color(0xFF3F51B5),
    );
  });

  test('la memoria ha un tetto: la settima palette fa posto alla prima', () {
    final prima = palette('p0', '#3f51b5');
    final temaPrima = AppTheme.tema(prima, Brightness.light);

    for (var indice = 1; indice < 7; indice++) {
      AppTheme.tema(
        palette('p$indice', '#$indice' '0$indice' '0$indice' '0'),
        Brightness.light,
      );
    }

    expect(
      identical(temaPrima, AppTheme.tema(prima, Brightness.light)),
      isFalse,
      reason: 'la prima è uscita dalla memoria: si ricostruisce',
    );
  });
}
