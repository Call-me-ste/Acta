import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../core/app_version.dart';
import '../../core/dev_flags.dart';
import '../../features/backup/backup_controller.dart';
import '../../features/backup/domain/backup_file.dart';
import '../../theme/design_tokens.dart';
import 'backup_sections.dart';

/// I pezzi minori della pagina delle copie: i due dialoghi e le due righe
/// informative che servono a **tutte e due** le modalità.
///
/// Stanno in un file loro per il tetto delle 300 righe — la pagina e le sezioni
/// erano arrivate al limite — e perché sono la parte che non decide niente: un
/// dialogo che chiede sì o no, e due righe da leggere.

/// «Ripristinare questa copia?» — dice **quale** copia e che i dati di adesso
/// vengono salvati prima.
Future<bool> chiediConfermaRipristino(
  BuildContext context,
  BackupFile copia,
) async {
  final conferma = await showActaDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ripristinare questa copia?'),
      scrollable: true,
      content: Text(
        'Copia del ${quandoBreve(copia.createdAt)}.\n\n'
        'Acta salva i dati attuali prima di sostituirli.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Ripristina'),
        ),
      ],
    ),
  );
  return conferma ?? false;
}

Future<bool> chiediConfermaRipristinoDaFile(
  BuildContext context,
  String nome,
) async =>
    await showActaDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ripristinare da file?'),
        scrollable: true,
        content: Text(
          'File: $nome\n\n'
          'Acta controlla il file e salva i dati attuali prima di sostituirli.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ripristina'),
          ),
        ],
      ),
    ) ??
    false;

/// «Quante copie tenere»: la scelta torna al chiamante, che la scrive.
Future<int?> chiediQuanteCopie(BuildContext context, int attuale) {
  var scelta = attuale;
  return showActaDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Quante copie tenere'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$scelta copie',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: scelta.toDouble(),
              min: 3,
              max: 50,
              divisions: 47,
              label: '$scelta',
              onChanged: (valore) => setState(() => scelta = valore.round()),
            ),
            Text(
              'Le copie più vecchie vengono cancellate. Le due di emergenza '
              'restano sempre.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(scelta),
            child: const Text('Salva'),
          ),
        ],
      ),
    ),
  );
}

/// Quello che Android **non** dice: non avvisa l'app quando la si disinstalla.
///
/// Sta in fondo alla pagina, perche' si legge una volta e serve una volta — ma
/// quella volta serve davvero: e' l'unico modo di perdere tutti i dati in un tocco.
class BackupPrimaDiDisinstallare extends StatelessWidget {
  const BackupPrimaDiDisinstallare({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Text(
            'Prima di disinstallare (o di cambiare telefono): Android non avvisa '
            'l\'app, quindi le copie qui dentro spariscono con lei. Esporta una '
            'copia e mettila su Drive o sul computer.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Versione dell'app e versione dello schema: le due cose da dire quando si
/// segnala un problema.
class BackupVersione extends StatelessWidget {
  const BackupVersione({super.key, required this.copie});

  final BackupController copie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m),
      child: Text(
        'Planner ${AppVersion.full}$devMarker · schema dati ${copie.schemaVersion}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// La riga rossa in testa: l'ultima cosa andata storta (una copia non riuscita,
/// una cartella sparita). Sta **in alto** e non in fondo perche' e' la ragione
/// per cui si e' aperta questa pagina.
class BackupAvviso extends StatelessWidget {
  const BackupAvviso(this.messaggio, {super.key});

  final String messaggio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('avviso-copie'),
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              messaggio,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
