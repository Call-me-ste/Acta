import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/app_version.dart';

/// La versione sta in **due** posti: `lib/core/app_version.dart` (che la mostra
/// in Impostazioni) e `pubspec.yaml` (che diventa `versionCode`/`versionName`
/// della build). Due posti che si allontanano sono la norma, non l'eccezione:
/// qui si pretende che dicano la stessa cosa, cosi' la pagina «Dati e backup»
/// non puo' mentire su quale build sta girando.
///
/// Non serve a niente leggere la versione da `pubspec.yaml` a runtime
/// (`package_info_plus` sarebbe una dipendenza in piu' per due stringhe): serve
/// che i due numeri **non possano** divergere senza che un test se ne accorga.
void main() {
  test('la versione in codice e quella di pubspec dicono la stessa cosa', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);

    expect(
      match,
      isNotNull,
      reason: 'pubspec.yaml deve avere una riga "version:" (es. 1.1.0+2)',
    );
    expect(
      match!.group(1),
      AppVersion.full,
      reason: 'pubspec.yaml dice "version: ${match.group(1)}" ma il codice dice '
          '"${AppVersion.full}": si aggiornano insieme, sempre (vedi '
          'lib/core/app_version.dart)',
    );
  });

  test('il numero di build e la versione hanno la forma giusta', () {
    // `versionCode` di Android e' un intero: un build a zero o scritto come
    // stringa rompe l'installazione in un modo che si vede solo sul telefono.
    expect(AppVersion.build, greaterThan(0));
    expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(AppVersion.name), isTrue,
        reason: 'il nome versione ha tre numeri: ${AppVersion.name}');
    expect(AppVersion.full, '${AppVersion.name}+${AppVersion.build}');
  });
}
