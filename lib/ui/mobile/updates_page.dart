import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_version.dart';
import '../../features/updates/update_controller.dart';
import '../../theme/design_tokens.dart';
import '../shared/settings_section.dart';
import 'update_banner.dart';

class UpdatesPage extends StatelessWidget {
  const UpdatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UpdateController?>();
    final status = controller?.status ?? UpdateCheckStatus.unsupported;
    final update = controller?.available;
    final sections = [
      SettingsSection(
        title: 'Versione installata',
        children: [
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text('Acta ${AppVersion.name}'),
            subtitle: Text('Build ${AppVersion.build}'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.refresh),
            title: const Text('Controlla aggiornamenti'),
            subtitle: Semantics(liveRegion: true, child: Text(_label(status))),
            trailing: status == UpdateCheckStatus.checking
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: switch (status) {
              UpdateCheckStatus.checking ||
              UpdateCheckStatus.unsupported =>
                null,
              _ => () => controller?.check(manual: true),
            },
          ),
          if (update != null)
            UpdateInstallTile(key: ValueKey(update.build), update: update),
        ],
      ),
      const SettingsSection(
        title: 'Cosa c’è di nuovo',
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Controllo manuale'),
            subtitle: Text(
              'Puoi cercare una nuova versione. Le novità di quella '
              'installata si leggono anche offline.',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Avviso all’apertura'),
            subtitle: Text(
              'L’APK ufficiale per Android ti avvisa quando su GitHub '
              'è disponibile una versione compatibile.',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Copia di sicurezza prima di aggiornare'),
            subtitle: Text(
              'Acta verifica il database e gli allegati prima di aprire '
              'la pagina di download.',
            ),
          ),
        ],
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Aggiornamenti')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.xl,
        ),
        itemCount: sections.length,
        itemBuilder: (context, index) => sections[index],
      ),
    );
  }

  static String _label(UpdateCheckStatus status) => switch (status) {
        UpdateCheckStatus.idle => 'Cerca una versione stabile su GitHub',
        UpdateCheckStatus.checking => 'Controllo in corso…',
        UpdateCheckStatus.available => 'Cerca di nuovo su GitHub',
        UpdateCheckStatus.noCompatibleUpdate =>
          'Nessun aggiornamento compatibile trovato',
        UpdateCheckStatus.noPublicRelease =>
          'Nessuna release pubblica di Acta trovata su GitHub',
        UpdateCheckStatus.unsupported =>
          'Controllo da GitHub non disponibile per questa installazione',
        UpdateCheckStatus.failed =>
          'Controllo non riuscito. Verifica la connessione e riprova.',
      };
}
