import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dev_flags.dart';
import '../../features/palette/palette_controller.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../theme/design_tokens.dart';
import '../../theme/color_resolver.dart';
import 'backup_page.dart';
import 'color_box.dart';
import 'colore_sheet.dart';
import 'demo_section.dart';
import 'import_events_page.dart';
import 'priority_page.dart';
import 'settings_extras.dart';
import 'todo_in_calendar_row.dart';
import 'updates_page.dart';
import '../shared/settings_section.dart';

/// Le impostazioni: **com'è fatta** l'app (aspetto) e cosa fa (sincronizzazione;
/// più avanti notifiche e backup).
///
/// Un solo elenco invece di una pagina per argomento: le impostazioni di un'app
/// personale sono poche, e un menù che porta a un menù è un passo in più per
/// niente.
///
/// Sotto «Aspetto» ci sono **due scelte** e basta: chiaro/scuro/sistema e il
/// tema coi colori. Tutto il resto vive nel foglio (`colore_sheet.dart`): la
/// pagina non mostra i singoli colori e non li ascolta, così cambiare colore non
/// la ricostruisce.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 0, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.xl,
        ),
        children: [
          const SettingsSection(
            title: 'Aspetto',
            children: [
              _ThemeModeSelector(),
              _ColoreRow(),
            ],
          ),
          SettingsSection(
            title: 'Organizzazione',
            children: [
              const CategorieRow(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Priorità'),
                subtitle: const Text('I colori dei quattro livelli'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _apri(context, const PriorityPage()),
              ),
              const TodoInCalendarRow(),
            ],
          ),
          const SettingsSection(
            title: 'Avvisi',
            children: [NotificheRow()],
          ),
          SettingsSection(
            title: 'Dati e backup',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_backup_restore),
                title: const Text('Copie di sicurezza'),
                subtitle: const Text('Backup, Google Drive e recupero'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _apri(context, const BackupPage()),
              ),
              ListTile(
                key: const ValueKey('impostazioni-importa-eventi'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('Importa eventi'),
                subtitle:
                    const Text('Dal calendario del telefono, una volta sola'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _apri(context, const ImportEventsPage()),
              ),
            ],
          ),
          SettingsSection(
            title: 'App',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.system_update_alt),
                title: const Text('Aggiornamenti'),
                subtitle: const Text('Controlla la versione e leggi le novità'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _apri(context, const UpdatesPage()),
              ),
            ],
          ),
          // I comandi di prova esistono solo nella build di test: con quello
          // che si compra `devTools` è una costante falsa e la sezione (con le
          // sue stringhe) non entra nel binario.
          if (devTools)
            const SettingsSection(
              title: 'Dati di prova',
              children: [DemoSection()],
            ),
          // Le preferenze meno usate restano in fondo, in un pannello chiuso.
          const AvanzateSection(),
        ],
      ),
    );
  }

  static Future<void> _apri(BuildContext context, Widget pagina) =>
      apriPagina(context, pagina);
}

/// La riga **«Tema e colori»**: il colore attivo si **vede** (una pastiglia col
/// colore del tema e i pallini degli elementi) e il foglio si apre toccandola.
///
/// Stessa altezza della pillola Sistema/Chiaro/Scuro: sono le due scelte della
/// stessa sezione, e una riga piu' bassa accanto a un comando importante si legge
/// come una nota a pie' di pagina. Piccola e sua: `watch` su quello che mostra —
/// così un cambio di colore ricostruisce questa riga (e il foglio), non la pagina
/// delle impostazioni.
class _ColoreRow extends StatelessWidget {
  const _ColoreRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = context.watch<AppSettingsController>();
    final palettes = context.watch<PaletteController>();
    final attiva = palettes.resolve(settings.activePaletteId);
    final colore = ColorResolver.hexToColor(attiva.seedHex) ?? scheme.primary;

    return InkWell(
      key: const ValueKey('aspetto-colore'),
      onTap: () => showColoreSheet(context),
      // Almeno il bersaglio di sistema (48), che cresce col testo come la
      // pillola qui sopra: un **minimo**, non un'altezza fissa — col testo
      // molto ingrandito la riga cresce invece di tagliare il testo.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.textScalerOf(context).scale(AppSpacing.touchTarget),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
          child: Row(
            children: [
              // Il colore attivo, **con** i colori degli elementi: e' quello che
              // dice a colpo d'occhio che tema si sta guardando.
              Container(
                key: const ValueKey('anteprima-colore'),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colore,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                alignment: Alignment.center,
                child: ColorStrip(palette: attiva),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tema e colori', style: theme.textTheme.titleSmall),
                    Text(
                      nomeDelColore(attiva, tono: palettes.tono),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.m),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sistema / Chiaro / Scuro. La scelta è per device e non entra nel sync.
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: AppSettingsController.themeSystem,
            label: Text('Sistema'),
          ),
          ButtonSegment(
            value: AppSettingsController.themeLight,
            label: Text('Chiaro'),
          ),
          ButtonSegment(
            value: AppSettingsController.themeDark,
            label: Text('Scuro'),
          ),
        ],
        selected: {settings.themeMode},
        showSelectedIcon: false,
        onSelectionChanged: (selection) =>
            settings.setThemeMode(selection.first),
      ),
    );
  }
}
