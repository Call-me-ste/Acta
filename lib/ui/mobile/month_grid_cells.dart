import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../features/calendar/month_grid_geometry.dart';
import '../../features/events/domain/event_occurrence.dart';
import '../../theme/design_tokens.dart';
import '../shared/date_math.dart';
import 'month_grid_painter.dart';

/// La **preparazione** della griglia: tutto quello che si misura una volta per
/// disegno (i nomi dei giorni, i numeri, i «+N», i badge) e che il painter poi
/// disegna.
///
/// Sta fuori da `month_grid.dart` per due ragioni: il file della griglia ha un
/// tetto di righe, e queste sono funzioni **pure** — prendono uno stile e
/// restituiscono un paragrafo misurato — quindi si leggono e si provano senza
/// un albero di widget.

/// Quante barre si disegnano in una cella: oltre la terza si conta col «+N».
const int barreMassime = 3;

/// Il lato della scatola del numero: è il limite dentro cui il paragrafo si
/// taglia. A testo normale basta 30; con il testo grande la scatola cresce
/// quanto il numero, altrimenti le due cifre vengono tagliate.
const double latoNumeroBase = 30;

/// Le misure della cella del mese derivate dal **contenuto**, non dalla scala
/// del testo applicata all'intera scatola. A 2.0 la riga non raddoppia: cresce
/// quanto serve al numero, alle barre e al «+N».
class MisureMese {
  const MisureMese({
    required this.rowHeight,
    required this.headerHeight,
    required this.latoNumero,
  });

  final double rowHeight;
  final double headerHeight;
  final double latoNumero;

  factory MisureMese.di(
    BuildContext context, {
    required double cellWidth,
  }) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final numero = theme.textTheme.bodyLarge!;
    final nomi = theme.textTheme.labelSmall!;

    final lineNumero =
        scaler.scale(numero.fontSize ?? 16) * (numero.height ?? 1.2);
    final lineNomi = scaler.scale(nomi.fontSize ?? 11) * (nomi.height ?? 1.2);

    // Il cerchio e il numero crescono insieme; non oltre la cella, o il
    // bersaglio del giorno esce dalla griglia.
    final lato = math.min(
      math.max(latoNumeroBase, lineNumero + AppSpacing.xs),
      math.max(latoNumeroBase, cellWidth - AppSpacing.xs / 2),
    );

    // Numero + bordo alto + tre barre + margine. La riga riserva **sempre** lo
    // spazio del «+N»: se lo aggiungesse solo quando arriva un giorno pieno,
    // tutte le celle crescerebbero dopo il caricamento dei dati (glitch visto
    // sul telefono il 21/10).
    const barre = barreMassime *
        (GrigliaDelMese.altezzaBarra + GrigliaDelMese.distaccoBarra);
    final row = math.max(
      AppSpacing.touchTarget,
      lato + 3 + barre + AppSpacing.xs + AppSpacing.m,
    );

    return MisureMese(
      rowHeight: row,
      headerHeight: lineNomi + AppSpacing.xs,
      latoNumero: lato,
    );
  }
}

/// Gli stili con cui si disegna un mese, risolti una volta per disegno.
class StiliDelMese {
  const StiliDelMese({
    required this.numero,
    required this.oltre,
    required this.badge,
    required this.nomi,
  });

  /// Il numero del giorno (`bodyLarge`, poi il colore e il peso li decide
  /// [stileDelNumero]).
  final TextStyle numero;

  /// Il «+N» oltre la terza barra.
  final TextStyle oltre;

  /// Il numero dentro il badge dei todo.
  final TextStyle badge;

  /// I nomi dei giorni in cima.
  final TextStyle nomi;

  factory StiliDelMese.di(ThemeData theme, ColorScheme scheme) {
    final labelSmall = theme.textTheme.labelSmall!;
    return StiliDelMese(
      numero: theme.textTheme.bodyLarge!,
      oltre: labelSmall.copyWith(
        fontSize: AppType.nano,
        color: scheme.onSurfaceVariant,
      ),
      badge: labelSmall.copyWith(
        color: scheme.onTertiary,
        fontSize: AppType.micro,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
      nomi: labelSmall.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// I sette nomi in cima (`dom lun mar…`), misurati con lo stile dato.
///
/// Sono sempre gli stessi sette: sette `DateFormat` a ogni disegno sarebbero
/// lavoro sprecato, quindi chi chiama tiene il risultato finché lo stile non
/// cambia.
List<TextPainter> nomiDeiGiorni(MonthGridGeometry geometria, TextStyle stile) {
  // Lo stesso formato che usava `table_calendar` per la sua intestazione.
  final format = DateFormat.E('it_IT');
  return [
    for (var colonna = 0; colonna < MonthGridGeometry.colonne; colonna++)
      misura(
        format.format(DateTime(
          geometria.primo.year,
          geometria.primo.month,
          geometria.primo.day + colonna,
        )),
        stile,
      ),
  ];
}

/// Lo stile del numero, interpolato fra «non scelto» e «scelto»: è quello che
/// faceva `AnimatedDefaultTextStyle`, fatto a mano perché colore e peso devono
/// seguire l'evidenza del cerchio.
TextStyle stileDelNumero({
  required TextStyle base,
  required ColorScheme scheme,
  required bool oggi,
  required bool fuori,
  required double evidenza,
}) {
  TextStyle mira({required bool scelto}) => base.copyWith(
        color: scelto
            ? scheme.onPrimary
            : oggi
                ? scheme.primary
                : fuori
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
                    : scheme.onSurface,
        fontWeight: oggi || scelto ? FontWeight.w600 : FontWeight.w500,
      );

  return TextStyle.lerp(mira(scelto: false), mira(scelto: true), evidenza)!;
}

/// Un testo misurato. Con [larghezzaMassima] il paragrafo si limita a quella
/// larghezza (ed è così che il numero si taglia quando non ci sta: col font dei
/// test, che ha glifi larghi un em, due cifre dentro i 30 px non ci stanno).
TextPainter misura(
  String testo,
  TextStyle? stile, {
  double larghezzaMassima = double.infinity,
}) =>
    TextPainter(
      text: TextSpan(text: testo, style: stile),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: larghezzaMassima);

/// Un giorno pronto da disegnare: numero (misurato dentro i 30 px della sua
/// scatola), barre degli eventi e badge dei todo.
///
/// È una funzione e non un metodo della griglia perché **non sa niente di
/// stato**: le si dice che giorno è, che mese si sta guardando e che dati ci
/// sono. Il colore degli eventi arriva da fuori (`coloreEvento`), perché dipende
/// dalla palette, che è roba di widget.
GiornoPronto preparaGiorno({
  required int indice,
  required DateTime giorno,
  required DateTime mese,
  required DateTime selezione,
  required DateTime oggi,
  required StiliDelMese stili,
  required ColorScheme scheme,
  required Map<DateTime, List<EventOccurrence>> eventsByDay,
  required Map<DateTime, int> todoCounts,
  required Color Function(EventOccurrence evento) coloreEvento,
  required double larghezzaNumero,
  double? evidenza,
}) {
  final chiave = dateOnly(giorno);
  final fuori = chiave.month != mese.month || chiave.year != mese.year;
  final scelto = chiave == dateOnly(selezione);
  final proprioOggi = chiave == dateOnly(oggi);
  final valore = evidenza ?? (scelto ? 1.0 : 0.0);

  final eventi = fuori
      ? const <EventOccurrence>[]
      : (eventsByDay[chiave] ?? const <EventOccurrence>[]);
  final todo = fuori ? 0 : (todoCounts[chiave] ?? 0);
  final oltre = eventi.length > barreMassime ? eventi.length - barreMassime : 0;

  return GiornoPronto(
    indice: indice,
    numero: misura(
      '${giorno.day}',
      stileDelNumero(
        base: stili.numero,
        scheme: scheme,
        oggi: proprioOggi,
        fuori: fuori,
        evidenza: valore,
      ),
      larghezzaMassima: larghezzaNumero,
    ),
    evidenza: valore,
    barre: [
      for (final evento in eventi.take(barreMassime)) coloreEvento(evento),
    ],
    oltre: oltre == 0 ? null : misura('+$oltre', stili.oltre),
    badge: todo == 0 ? null : misura('$todo', stili.badge),
  );
}
