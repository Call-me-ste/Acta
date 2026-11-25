/// Come si traduce il tema **dell'app** nei colori che il widget si porta dietro.
///
/// Sta in un file suo e non dentro la guardia per due ragioni: il tetto delle 300
/// righe (`test/architecture_test.dart`), e perché è la parte che si legge da sola
/// — «questo ruolo del tema diventa questo colore nel pacchetto» — mentre la
/// guardia è la parte che sa *quando* ripubblicare.
///
/// I colori escono come stringhe `#rrggbb`: il renderer Kotlin non sa cosa sia un
/// `ColorScheme`, e non deve saperlo (disegna quello che riceve).
library;

import 'dart:ui' show Brightness;

import 'package:flutter/material.dart' show Color, ColorScheme;

import '../../features/palette/domain/palette.dart';
import '../../features/todos/domain/todo.dart';
import '../../features/widgets/domain/widget_payload.dart';
import '../../theme/app_theme.dart';
import '../../theme/color_resolver.dart';
import 'formatters.dart';

/// I due temi (chiaro e scuro) nei sei ruoli che il widget usa.
///
/// Due e non uno perché il widget vive sulla schermata home: lì decide il
/// **sistema** (chiaroscuro), non la scelta fatta dentro l'app. I colori però sono
/// quelli della palette attiva, così il widget e l'app si somigliano.
WidgetTema temaDelWidget(Palette palette) => WidgetTema(
      chiaro: coloriDelTema(AppTheme.schemeFor(palette, Brightness.light)),
      scuro: coloriDelTema(AppTheme.schemeFor(palette, Brightness.dark)),
    );

Map<String, String> coloriDelTema(ColorScheme scheme) => {
      'sfondo': ColorResolver.colorToHex(scheme.surface),
      'superficie': ColorResolver.colorToHex(scheme.surfaceContainerHigh),
      'testo': ColorResolver.colorToHex(scheme.onSurface),
      'testoTenue': ColorResolver.colorToHex(scheme.onSurfaceVariant),
      'accento': ColorResolver.colorToHex(scheme.primary),
      'bordo': ColorResolver.colorToHex(scheme.outlineVariant),
    };

/// Il colore di un todo nel widget: quello scelto per l'elemento, e se non ce n'è
/// uno **quello della priorità** — la stessa distinzione che fa l'app (il colore
/// dell'elemento sull'anello, la priorità come segno).
///
/// [ripiego] è il colore del tema, che serve solo se l'hex della priorità è scritto
/// male (un'impostazione rotta): un widget che sparisce è peggio di un widget col
/// colore del tema.
String coloreTodoDelWidget(
  Todo elemento,
  Palette palette, {
  required Brightness intensita,
  required List<String> priorita,
  required Color ripiego,
}) {
  final indice = elemento.colorIndex;
  if (indice != null) {
    return ColorResolver.colorToHex(
      ColorResolver.elementColor(
        palette: palette,
        brightness: intensita,
        index: indice,
      ),
    );
  }

  final hex = priorita[elemento.priority.clamp(0, priorita.length - 1)];
  final base = ColorResolver.hexToColor(hex) ?? ripiego;
  return ColorResolver.colorToHex(
    intensita == Brightness.dark ? ColorResolver.darkVariant(base) : base,
  );
}

/// L'intestazione del giorno sul widget: `Oggi · gio 24 set`, oppure `gio 25 set`
/// per gli altri giorni del pacchetto.
///
/// La parola «Oggi» la decide chi guarda il calendario, non il widget: il
/// pacchetto viene scritto oggi, e domani quella riga deve continuare a dire il
/// vero — quindi il primo giorno del pacchetto è «Oggi» **finché lo è**.
String etichettaDelGiorno(DateTime giorno, DateTime adesso) {
  final breve = dataBreve(giorno);
  final oggi = giorno.year == adesso.year &&
      giorno.month == adesso.month &&
      giorno.day == adesso.day;
  return oggi ? 'Oggi · $breve' : breve;
}

/// L'intestazione del **mese** sul widget mensile: `settembre 2026`.
///
/// Sta qui accanto a quella del giorno perché è la stessa voce: i nomi dei mesi
/// sono quelli dell'app (`formatters.dart`), non quelli del launcher.
String etichettaDelMese(DateTime mese) => meseAnno(mese);
