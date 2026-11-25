import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Il postmortem della v2 (`docs/v2-postmortem.md`) reso eseguibile.
///
/// Una convenzione non è una garanzia: la v2 aveva regole anti-stutter scritte
/// nel prompt e `home_page.dart` è arrivato a 5.323 righe lo stesso. Qui le due
/// regole che hanno ucciso la v2 diventano un test che fallisce.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('lib/ non ha file monstre', () {
    const maxLines = 300;
    final offenders = <String>[];
    for (final file in dartFiles) {
      final lines = file.readAsLinesSync().length;
      if (lines > maxLines) offenders.add('${file.path}: $lines righe');
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Il nemico della v2 non era lo stutter, era la dimensione: '
          'home_page.dart a 5.323 righe rendeva ogni task un\'indagine infinita. '
          'Un file oltre $maxLines righe va spezzato. Violazioni: $offenders',
    );
  });

  test('il disegno non usa costrutti che creano un saveLayer', () {
    // Un `saveLayer` costa una superficie in più **per fotogramma**: è il modo
    // più semplice per far scattare un'interfaccia che sembrava fluida, e il
    // piano lo vieta nel trace di rendering. Una misura una volta sola non
    // basta: qui diventa una regola, sulla lista corta dei costrutti che lo
    // provocano. Al posto loro ci sono i colori con alpha (`withValues`) e le
    // transizioni implicite, che non alloccano niente.
    const forbidden = [
      'BackdropFilter', // vetro sfocato: una passata di blur per fotogramma
      'ImageFilter', // idem, anche fuori da un filtro di sfondo
      'ShaderMask', // maschera di shader: superficie separata
      'Opacity(', // opacità animata (`AnimatedOpacity`, `Opacity`): idem
    ];
    final offenders = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final token in forbidden) {
        if (source.contains(token)) offenders.add('${file.path}: $token');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Questi costrutti creano un saveLayer, cioè una superficie in più '
          'per fotogramma. Violazioni: $offenders',
    );
  });

  test('le misure del form vengono dai token', () {
    // La segnalazione era «pulsanti grandi rispetto alle scritte, incoerenza
    // grafica»: nel form convivevano righe da 56-72 px, un `left: 56` scritto a
    // mano, spazi 8/12/16 nudi e un pulsante da 40 accanto a etichette da 11.
    // Le misure stanno nei token (`AppSpacing`, `AppRadius`, `AppType`) e questa
    // regola vale **sui file del form**, dove la coerenza si vede a occhio.
    const formFiles = {
      'lib/ui/mobile/item_form.dart',
      'lib/ui/mobile/item_actions.dart',
      'lib/ui/mobile/item_common_fields.dart',
      'lib/ui/mobile/event_section.dart',
      'lib/ui/mobile/event_time_fields.dart',
      'lib/ui/mobile/todo_section.dart',
      'lib/ui/shared/picker_tile.dart',
      'lib/ui/shared/form_section_title.dart',
      'lib/ui/shared/recurrence_field.dart',
      'lib/ui/shared/palette_color_row.dart',
    };

    // Le tre forme in cui una misura nuda si nasconde: uno spazio, un margine,
    // una dimensione del testo. `AppSpacing.s` non è un numero, quindi passa.
    final misureNude = <RegExp>[
      RegExp(r'SizedBox\((height|width): [0-9]'),
      RegExp(r'EdgeInsets\.(all|symmetric|only)\([^A)]*[0-9]'),
      RegExp(r'fontSize: [0-9]'),
      // Anche le icone: due misure in croce in tre file diversi sono esattamente
      // il modo in cui due schermate della stessa app sembrano due app.
      RegExp(r'size: [0-9]'),
    ];

    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = file.path.replaceAll(r'\', '/');
      if (!formFiles.contains(path)) continue;
      final source = file.readAsStringSync();
      for (final regola in misureNude) {
        if (regola.hasMatch(source)) {
          offenders.add('$path: ${regola.pattern}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Le misure del form vengono dai token: un numero nudo in un file '
          'e'
          ' in un altro è come nasce l\'incoerenza grafica. Violazioni: '
          '$offenders',
    );
  });

  test('i layout dei widget usano solo viste RemoteViews', () {
    // `android.view.View` non e' nella lista delle classi che il launcher puo'
    // gonfiare: il widget finisce in «Errore durante il caricamento» e il log
    // dell'app non dice niente, perche' il layout lo applica un altro processo.
    // La regola sta qui perche' e' gia' successa due volte (barrette e pallini).
    final layout = Directory('android/app/src/main/res/layout');
    final offenders = <String>[];
    for (final file in layout.listSync().whereType<File>()) {
      if (!file.path.endsWith('.xml')) continue;
      final source = file.readAsStringSync();
      if (RegExp(r'<View\b').hasMatch(source)) offenders.add(file.path);
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Nei RemoteViews usare ImageView/TextView, non View. '
          'Violazioni: $offenders',
    );
  });

  test('la logica non dipende dai widget', () {
    // Il layer dati/logica deve restare usabile (e testabile) senza UI: è ciò
    // che permette di condividere tutto fra la shell mobile e quella desktop
    // invece di duplicare il progetto.
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = file.path.replaceAll(r'\', '/');
      // Il confine è dichiarato: logica = core/ + features/, UI = ui/. Tutto
      // ciò che sta a monte della UI deve restare usabile senza widget, perché
      // è la condizione per condividere il codice fra mobile e desktop invece
      // di duplicare il progetto.
      final isLogicLayer =
          path.startsWith('lib/core/') || path.startsWith('lib/features/');
      if (!isLogicLayer) continue;
      if (file.readAsStringSync().contains('package:flutter/material.dart')) {
        offenders.add(path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'La logica non deve importare Material. '
          'Violazioni: $offenders',
    );
  });

  test('i plugin si importano da un file solo', () {
    // Un plugin che compare in dieci file non si puo' piu' ne' sostituire ne'
    // provare: il sink delle notifiche e il ponte dei widget esistono per questo —
    // un solo file sa dove stanno i dati del sistema e come si sveglia l'app,
    // tutto il resto parla con un'interfaccia e si prova con una finta. Era una
    // promessa scritta nei commenti: qui diventa una regola.
    const ponti = {
      'package:flutter_local_notifications/':
          'lib/features/notifications/flutter_local_notifications_sink.dart',
      'package:home_widget/': 'lib/features/widgets/home_widget_bridge.dart',
    };

    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = file.path.replaceAll(r'\', '/');
      final source = file.readAsStringSync();
      for (final ponte in ponti.entries) {
        if (!source.contains(ponte.key)) continue;
        if (path != ponte.value) offenders.add('$path importa ${ponte.key}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Un plugin si importa dal suo ponte, uno solo. Violazioni: '
          '$offenders',
    );
  });

  test('le durate delle animazioni vengono dai token', () {
    // Una durata scritta a mano non segue la regola delle altre: il giorno in cui
    // si decidono movimenti un po' piu' lenti (ed e' successo, su richiesta
    // dell'utente: rallentare tutto per non far vedere gli scatti) quella resta
    // indietro e diventa l'eccezione che nessuno ricorda. Come le misure del
    // form, anche le durate stanno in un posto solo.
    //
    // Il confine e' dichiarato: nella UI (`lib/ui/`) le durate vengono da
    // `AppMotion`; fuori dalla UI quelle che si trovano non sono animazioni ma
    // aritmetica di date (`features/`) e attese di una sonda di sviluppo.
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.startsWith('lib/ui/')) continue;
      // L'unica eccezione dichiarata: la sonda di sviluppo (`switchProbe`) aspetta
      // un secondo e mezzo fra un cambio di vista e l'altro per far girare le
      // animazioni da sola. Non e' un'animazione: e' uno strumento di misura, e
      // non esiste nella build normale.
      if (path.endsWith('switch_probe.dart')) continue;
      if (RegExp(r'Duration\(\s*milliseconds:')
          .hasMatch(file.readAsStringSync())) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Le durate delle animazioni stanno in AppMotion '
          '(theme/design_tokens.dart), un posto solo, cosi\' si alzano tutte '
          'insieme. Violazioni: $offenders',
    );
  });
}
