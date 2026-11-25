import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/database/database_files.dart';
import '../../core/database/database_service.dart';
import '../../core/storage_failure.dart';
import '../../features/backup/backup_controller.dart';
import '../../features/backup/backup_export.dart';
import '../../features/backup/domain/backup_file.dart';
import '../../features/backup/portable_encrypted_backup.dart';
import '../../features/categories/category_controller.dart';
import '../../features/events/event_provider.dart';
import '../../features/notes/note_provider.dart';
import '../../features/notes/note_attachment_store.dart';
import '../../features/palette/palette_controller.dart';
import '../../features/todos/todo_filter_controller.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/sync/sync_controller.dart';
import '../../theme/design_tokens.dart';
import '../shared/formatters.dart';
import '../shared/opzioni_avanzate.dart';
import 'backup_extras.dart';
import 'backup_sections.dart';
import 'backup_simple.dart';
import 'note_attachment_recovery.dart';
import 'sync_settings_page.dart';

part 'backup_portable_actions.dart';
part 'backup_file_reader.dart';

/// Backup locali, esportazione e ripristino.
class BackupPage extends StatelessWidget {
  const BackupPage({super.key, this.condividi = condividiCopia});

  final Future<void> Function(String percorso) condividi;

  @override
  Widget build(BuildContext context) {
    final copie = context.watch<BackupController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Dati e backup')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          if (copie.errore != null) BackupAvviso(copie.errore!),
          BackupPaginaSemplice(
            copie: copie,
            onEsporta: () => _esporta(context),
            onImporta: () => _importa(context),
            onRipristina: (copia) => _chiediRipristino(context, copia),
            drive: const DriveBackupTile(),
          ),
          const SecurityRecoveryTile(),
          const Divider(height: AppSpacing.xl),
          OpzioniAvanzate(
            key: const ValueKey('backup-opzioni-avanzate'),
            nota: 'Copia manuale, dettagli e altri strumenti',
            children: [
              BackupRiepilogo(copie: copie),
              const Divider(height: AppSpacing.xl),
              BackupComandi(
                copie: copie,
                onCopia: () => _faiCopia(context),
                onVerifica: () => _verificaDatabase(context),
                onCompatta: () => _compatta(context),
              ),
              const Divider(height: AppSpacing.xl),
              BackupElencoCopie(
                copie: copie,
                onScegli: (copia) => _chiediRipristino(context, copia),
              ),
              const Divider(height: AppSpacing.xl),
              BackupCopieDaTenere(
                copie: copie,
                onCambia: () => _cambiaRetention(context),
              ),
              BackupVersione(copie: copie),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Azioni ───────────────────────────────────────────

  Future<void> _faiCopia(BuildContext context) async {
    final copie = context.read<BackupController>();
    if (copie.occupato) return;
    await copie.adesso();
    if (!context.mounted) return;
    _dici(
      context,
      copie.errore == null ? 'Copia fatta: ${_elenco(copie)}' : copie.errore!,
    );
  }

  /// Esporta una nuova copia dal database corrente.
  Future<void> _esporta(BuildContext context) async {
    final copie = context.read<BackupController>();
    if (copie.occupato) return;
    await copie.adesso();
    if (!context.mounted) return;

    if (copie.errore != null) {
      _dici(context, copie.errore!);
      return;
    }
    final ultima = copie.copie.firstOrNull;
    if (ultima == null) {
      _dici(context, 'Non c\'è nessuna copia da esportare');
      return;
    }
    final store = context.read<NoteAttachmentStore?>();
    final file = File(p.join(copie.percorsoCartella, ultima.name));
    try {
      if (store != null) {
        await _condividiCifrata(context, store, copie, file);
      } else {
        await condividi(file.path);
      }
    } catch (error) {
      if (context.mounted) {
        _dici(
            context,
            switch (error) {
              PortableBackupTooLarge() => error.message,
              _ when isDeviceStorageFull(error) => deviceStorageFullMessage,
              _ =>
                'Impossibile preparare la copia cifrata. Controlla gli allegati e riprova.',
            });
      }
      return;
    }
  }

  Future<void> _importa(BuildContext context) async {
    if (!Platform.isAndroid) {
      _dici(context, 'Il selettore delle copie è disponibile su Android');
      return;
    }
    Map<String, String>? scelto;
    try {
      scelto = await _leggiCopia(context);
    } on PlatformException catch (error) {
      if (context.mounted) _dici(context, _backupPickerMessage(error.code));
      return;
    }
    final percorso = scelto?['path'];
    if (percorso == null) return;

    try {
      if (!context.mounted) return;
      final conferma = await chiediConfermaRipristinoDaFile(
        context,
        scelto?['name'] ?? 'copia',
      );
      if (!conferma || !context.mounted) return;

      final copie = context.read<BackupController>();
      final store = context.read<NoteAttachmentStore?>();
      if (store != null &&
          (scelto?['name'] ?? '')
              .toLowerCase()
              .endsWith(PortableEncryptedBackup.extension)) {
        if (!await _ripristinaCifrata(context, store, copie, File(percorso))) {
          return;
        }
      } else {
        await _conSyncInPausa(context, () => copie.ripristinaEsterna(percorso));
      }
      if (!context.mounted) return;
      if (copie.errore == null) _ricaricaTutto(context);
      _dici(context, copie.errore ?? 'Copia ripristinata dal file');
    } on StateError catch (error) {
      if (context.mounted) _dici(context, error.message);
    } finally {
      try {
        await File(percorso).delete();
      } on FileSystemException {
        // È una copia nella cache dell'app.
      }
    }
  }

  Future<void> _verificaDatabase(BuildContext context) async {
    final database = context.read<DatabaseService>();
    final esito = database.integrita();
    _dici(
      context,
      esito == 'ok'
          ? 'Database integro'
          : 'La verifica dei dati non è riuscita. Controlla le copie disponibili.',
    );
  }

  Future<void> _compatta(BuildContext context) async {
    final copie = context.read<BackupController>();
    final esito = await copie.compatta();
    if (!context.mounted) return;

    if (esito == null) {
      _dici(context, copie.errore ?? 'La compattazione non è riuscita');
      return;
    }
    final restituiti = esito.bytePrima - esito.byteDopo;
    _dici(
      context,
      restituiti <= 0 && esito.righe == 0
          ? 'Non c\'era niente da restituire'
          : 'Restituiti ${peso(restituiti)}, tolte ${esito.righe} righe in coda',
    );
  }

  Future<void> _chiediRipristino(BuildContext context, BackupFile copia) async {
    if (!await chiediConfermaRipristino(context, copia)) return;
    if (!context.mounted) return;

    final copie = context.read<BackupController>();
    try {
      await _conSyncInPausa(context, () => copie.ripristina(copia));
    } on StateError catch (error) {
      if (context.mounted) _dici(context, error.message);
      return;
    }
    if (!context.mounted) return;

    if (copie.errore != null) {
      _dici(context, copie.errore!);
      return;
    }
    _ricaricaTutto(context);
    _dici(context, 'Ripristinata la copia del ${_quando(copia.createdAt)}');
  }

  /// Dopo un ripristino il database contiene righe che le viste non hanno mai
  /// visto: **si rileggono tutte**. Senza, la schermata mostrerebbe i dati di
  /// prima del ripristino, che e' il modo peggiore di raccontare cosa e'
  /// successo.
  void _ricaricaTutto(BuildContext context) {
    context.read<EventProvider>().reload();
    context.read<TodoProvider>().reload();
    context.read<CategoryController>().load();
    context.read<PaletteController>().load();
    context.read<TodoFilterController>().load();
    context.read<NoteProvider?>()?.reload();
  }

  Future<void> _cambiaRetention(BuildContext context) async {
    final copie = context.read<BackupController>();
    final salvata = await chiediQuanteCopie(context, copie.retention);
    if (salvata == null || !context.mounted) return;
    copie.cambiaRetention(salvata);
    _dici(context, 'Tengo le ultime $salvata copie');
  }

  static String _elenco(BackupController copie) =>
      '${copie.copie.length} nella cartella';

  void _dici(BuildContext context, String messaggio) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(messaggio)));
  }

  static String _quando(DateTime quando) =>
      '${formatShortDay(quando)} ${formatTime(quando)}';
}
