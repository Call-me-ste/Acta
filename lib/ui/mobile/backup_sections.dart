import 'package:flutter/material.dart';

import '../../features/backup/backup_controller.dart';
import '../../features/backup/domain/backup_file.dart';
import '../../theme/design_tokens.dart';
import '../shared/formatters.dart';

/// I pezzi della pagina **Dati e backup**, uno per sezione.
///
/// Stanno fuori dalla pagina per il tetto delle 300 righe, e perche' ognuno si
/// legge da solo: cosa c'e' adesso, cosa posso fare, cosa c'e' nella cartella,
/// cosa succede se disinstallo.

/// Cosa c'e' adesso: ultima copia, peso del database, peso delle copie.
class BackupRiepilogo extends StatelessWidget {
  const BackupRiepilogo({super.key, required this.copie});

  final BackupController copie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ultima = copie.ultimaCopia;
    final database = copie.dimensioniDatabase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ultima copia', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ultima == null
              ? 'Nessuna copia: la prima arriva al prossimo avvio con dei dati'
              : '${quandoBreve(ultima)}  (${quantoFa(ultima)})',
          key: const ValueKey('ultima-copia'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.m),
        Text(
          'Database: ${peso(database.totale)}'
          '${database.wal > 0 ? ' (${peso(database.wal)} di WAL)' : ''} · '
          'Copie: ${peso(copie.dimensioneCopie)} in ${copie.copie.length} file',
          style: theme.textTheme.bodySmall,
        ),
        Text(
          copie.percorsoCartella,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// I comandi che si usano davvero, in ordine di frequenza.
class BackupComandi extends StatelessWidget {
  const BackupComandi({
    super.key,
    required this.copie,
    required this.onCopia,
    required this.onVerifica,
    required this.onCompatta,
  });

  final BackupController copie;
  final VoidCallback onCopia;
  final VoidCallback onVerifica;
  final VoidCallback onCompatta;

  @override
  Widget build(BuildContext context) {
    final occupato = copie.occupato;
    return Column(
      children: [
        if (occupato) const LinearProgressIndicator(),
        ListTile(
          key: const ValueKey('copia-adesso'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.save_outlined),
          title: const Text('Fai il backup adesso'),
          subtitle: const Text('Una copia verificata nella cartella dell\'app'),
          onTap: occupato ? null : onCopia,
        ),
        ListTile(
          key: const ValueKey('verifica-database'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.health_and_safety_outlined),
          title: const Text('Verifica il database'),
          subtitle:
              const Text('Controlla che le pagine del file siano leggibili'),
          onTap: onVerifica,
        ),
        ListTile(
          key: const ValueKey('compatta-adesso'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.compress),
          title: const Text('Compatta adesso'),
          subtitle: const Text(
            'Ripulisce la coda delle scritture e restituisce lo spazio',
          ),
          onTap: occupato ? null : onCompatta,
        ),
      ],
    );
  }
}

/// Le copie che ci sono, dalla piu' recente: toccandone una si puo' rimettere
/// dentro.
///
/// [quante] serve all'Utente Standard: ne mostra tre invece di tutte (chi ha paura
/// di perdere i dati vuole l'ultima, non l'elenco), e [titolo] perche' li' la
/// sezione si chiama «Ripristina una copia».
class BackupElencoCopie extends StatelessWidget {
  const BackupElencoCopie({
    super.key,
    required this.copie,
    required this.onScegli,
    this.quante,
    this.titolo = 'Copie nella cartella',
  });

  final BackupController copie;
  final void Function(BackupFile copia) onScegli;
  final int? quante;
  final String titolo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (copie.copie.isEmpty) {
      return Text(
        'Nella cartella non c\'è ancora nessuna copia.',
        style: theme.textTheme.bodyMedium,
      );
    }

    final mostrate = quante == null ? copie.copie : copie.copie.take(quante!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titolo, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final copia in mostrate)
          ListTile(
            key: ValueKey('copia-${copia.name}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              copia.eEmergenza ? Icons.shield_outlined : Icons.history,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(quandoBreve(copia.createdAt)),
            subtitle: Text(
              '${copia.reason?.etichetta ?? 'motivo non noto'} · '
              '${peso(copia.sizeBytes)}'
              '${copia.sidecar == null ? ' · senza foglio' : ''}',
            ),
            trailing: const Icon(Icons.settings_backup_restore),
            onTap: () => onScegli(copia),
          ),
      ],
    );
  }
}

/// Quante copie si tengono.
class BackupCopieDaTenere extends StatelessWidget {
  const BackupCopieDaTenere(
      {super.key, required this.copie, required this.onCambia});

  final BackupController copie;
  final VoidCallback onCambia;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('copie-da-tenere'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.layers_outlined),
      title: const Text('Copie da tenere'),
      subtitle:
          Text('Le ultime ${copie.retention} · le più vecchie si cancellano'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onCambia,
    );
  }
}

String quandoBreve(DateTime quando) =>
    '${formatShortDay(quando)} ${formatTime(quando)}';

/// «2 minuti fa», «3 ore fa», «5 giorni fa»: quanto e' vecchia la copia si legge per
/// decidere se fidarsene, e «4 ore» lo dice meglio di una data.
String quantoFa(DateTime quando) {
  final quanto = DateTime.now().difference(quando);
  if (quanto.inMinutes < 2) return 'pochi secondi fa';
  if (quanto.inMinutes < 60) return '${quanto.inMinutes} minuti fa';
  if (quanto.inHours < 24) return '${quanto.inHours} ore fa';
  return '${quanto.inDays} giorni fa';
}

/// «2,3 MB», «128 KB». Il peso si legge per capire se c'e' spazio, non per
/// contare i byte: due cifre significative bastano.
String peso(int byte) {
  if (byte < 1024) return '$byte B';
  final kb = byte / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
