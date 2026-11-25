import 'package:flutter/material.dart';

import '../features/palette/domain/palette.dart';
import 'color_resolver.dart';
import 'design_tokens.dart';

/// Il tema nasce dalla **palette attiva**: un seed per il colore delle superfici,
/// una lista di colori per gli elementi.
///
/// Chiaro e scuro sono due schemi generati separatamente (`ColorScheme.fromSeed`
/// con `brightness`): invertire il chiaro per fare lo scuro è il modo più rapido
/// per ottenere testo illeggibile e superfici sbagliate.
///
/// Le **forme** stanno qui e non nei singoli widget: un raggio deciso per widget
/// è il motivo per cui due schermate della stessa app sembrano di due app
/// diverse (ed è quello che l'utente aveva segnalato come "vecchio e squadrato").
/// Cambiare qui cambia tutta l'app in una riga.
class AppTheme {
  const AppTheme._();

  static ThemeData light(Palette palette) => tema(palette, Brightness.light);

  static ThemeData dark(Palette palette) => tema(palette, Brightness.dark);

  /// Lo schema di una palette, **memorizzato**.
  ///
  /// Perche': `ColorScheme.fromSeed` costa **2,15 ms** (misurato sul telefono il
  /// 2026-09-18, `docs/fluidita.md`) e i punti che disegnano un'anteprima lo
  /// chiedono a ogni build. Senza memoria, aprire il foglio dei colori e toccare
  /// sei tinte sono dodici generazioni di schema: ~26 ms di lavoro che si puo'
  /// semplicemente non rifare.
  static ColorScheme schemeFor(Palette palette, Brightness brightness) {
    final chiave = _chiave(palette, brightness);
    final memorizzato = _schemi[chiave];
    if (memorizzato != null) return memorizzato;

    final nuovo = ColorResolver.schemeFor(
      palette: palette,
      brightness: brightness,
    );
    _ricorda(_schemi, chiave, nuovo);
    return nuovo;
  }

  /// Il tema, memorizzato per (contenuto della palette, chiaro/scuro).
  ///
  /// Non velocizza il **cambio** tema — la palette e' nuova e va costruita (2 x
  /// 2,2 ms misurati: il resto del fotogramma pesante e' l'albero che si
  /// ridisegna) — ma toglie la ricostruzione da ogni **altra** ricostruzione, e la
  /// shell ne fa due a ogni build.
  static ThemeData tema(Palette palette, Brightness brightness) {
    final chiave = _chiave(palette, brightness);
    final memorizzato = _temi[chiave];
    if (memorizzato != null) return memorizzato;

    final nuovo = _costruisci(schemeFor(palette, brightness), brightness);
    _ricorda(_temi, chiave, nuovo);
    return nuovo;
  }

  /// Quante coppie (palette, chiaro/scuro) si tengono: le palette in gioco sono
  /// poche (quella attiva e quelle che si stanno guardando nel foglio).
  static const int _max = 6;
  static final Map<Object, ColorScheme> _schemi = {};
  static final Map<Object, ThemeData> _temi = {};

  /// La chiave e' il **contenuto** che conta per il tema (seed e i quattro colori),
  /// non l'id: due palette diverse non si confondono, e una modificata non
  /// restituisce il tema di prima.
  static Object _chiave(Palette palette, Brightness brightness) => (
        brightness,
        palette.seedHex,
        [
          for (final ruolo in Palette.simpleRoles)
            '$ruolo=${palette.simpleColors[ruolo] ?? ''}',
        ].join(','),
      );

  static void _ricorda<T>(Map<Object, T> memoria, Object chiave, T valore) {
    if (memoria.length >= _max) memoria.remove(memoria.keys.first);
    memoria[chiave] = valore;
  }

  static ThemeData _costruisci(ColorScheme scheme, Brightness brightness) {
    final soft = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
    );
    final large = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.large),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // Un carattere incorporato: su un telefono col font di sistema serif
      // l'app cambierebbe faccia. Inter è la base tipografica di tutta la UI.
      fontFamily: 'Inter',
      // Niente tinta sulle superfici: il colore arriva dal seed e basta, così le
      // superfici restano pulite invece di tingersi di viola a ogni elevazione.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: large,
        clipBehavior: Clip.antiAlias,
      ),
      // I chip sono pillole: palette, colori liberi, preset di ricorrenza,
      // eventi all-day. È il cambio che si vede di più.
      chipTheme: ChipThemeData(
        shape: AppRadius.pill,
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      // Azione principale a pillola; le secondarie restano arrotondate: la
      // gerarchia si legge dalla forma, non solo dal colore.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: AppRadius.pill,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.m,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        minVerticalPadding: AppSpacing.s,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: soft,
      ),
      datePickerTheme: DatePickerThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: scheme.outline),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.65),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorShape: AppRadius.pill,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: AppRadius.pill,
        elevation: 2,
        highlightElevation: 3,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(shape: AppRadius.pill),
      ),
    );
  }
}
