import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../features/palette/domain/palette.dart';
import '../features/palette/palette_controller.dart';
import '../features/settings/app_settings_controller.dart';
import '../theme/app_theme.dart';
import 'mobile/mobile_shell.dart';
import 'mobile/incoming_note_share.dart';
import 'mobile/notification_open_guard.dart';
import 'shared/widget_open.dart';

/// Il guscio dell'app: l'unico punto che decide *come* si presenta la stessa
/// logica su piattaforme diverse. Qui vivono anche lingua e localizzazioni
/// (l'app parla italiano a prescindere dalla lingua del dispositivo).
///
/// Oggi esiste una sola shell (mobile). Il ramo per il desktop — navigation rail
/// laterale, layout largo — arriva col passaggio desktop, come deciso: una
/// piattaforma alla volta. Tutto ciò che sta sotto (database, provider, sync)
/// è condiviso e non cambia fra le due.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    // Si guardano **solo** i valori che riguardano il tema, non tutte le
    // preferenze.
    //
    // Perche' conta: `watch` su tutto il controller ricostruiva `MaterialApp` (e con
    // esso tutto l'albero, compresa la pagina corrente) a **ogni** cambio di
    // preferenza — compresa la vista del calendario, che non c'entra niente col
    // tema. Era il fotogramma da 15-16 ms proprio all'inizio dell'animazione,
    // misurato sul telefono il 2026-09-17: l'"impuntamento" al primo tocco dopo una
    // pausa, e anche il glitch quando si toccava due volte di fila.
    final themeMode = context.select<AppSettingsController, ThemeMode>(
      (settings) => _themeMode(settings.themeMode),
    );
    final paletteId = context.select<AppSettingsController, String>(
      (settings) => settings.activePaletteId,
    );
    final palette =
        context.select<PaletteController, Palette>((p) => p.resolve(paletteId));
    final animationsEnabled = context.select<AppSettingsController, bool>(
      (settings) => settings.animationsEnabled,
    );

    return MaterialApp(
      title: 'Planner',
      debugShowCheckedModeBanner: false,
      navigatorKey: naveDaWidget,
      // L'app parla italiano anche se il telefono e' in un'altra lingua: e' il modo
      // per avere giorni e mesi in italiano su ogni dispositivo.
      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      themeMode: themeMode,
      themeAnimationStyle:
          animationsEnabled ? null : AnimationStyle.noAnimation,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: animationsEnabled
              ? media
              : media.copyWith(disableAnimations: true),
          child: child!,
        );
      },
      home: const NotificationOpenGuard(
        child: IncomingNoteShare(child: MobileShell()),
      ),
    );
  }

  /// Il tema scelto è una stringa nel database (la logica non importa Material):
  /// qui diventa il valore che serve a Flutter.
  static ThemeMode _themeMode(String value) {
    return switch (value) {
      AppSettingsController.themeLight => ThemeMode.light,
      AppSettingsController.themeDark => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
