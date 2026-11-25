part of 'backup_service.dart';

extension BackupAttachmentOperations on BackupService {
  BackupAttachmentFiles get _allegati => BackupAttachmentFiles(
        Directory(p.join(p.dirname(_database.path), 'note-attachments')),
        Directory(p.join(cartella.path, 'note-attachments')),
      );

  Future<void> _salvaAllegati(File temporaneo) async {
    try {
      await _allegati.save(temporaneo);
    } catch (error) {
      await temporaneo.delete();
      throw BackupFallito(
        isDeviceStorageFull(error)
            ? deviceStorageFullMessage
            : 'Copia incompleta. Scarica gli allegati da Drive e riprova.',
      );
    }
  }

  Future<BackupFile> _applica(File file) async {
    try {
      await _allegati.restore(file);
    } on FileSystemException catch (error) {
      throw BackupFallito(
        isDeviceStorageFull(error)
            ? deviceStorageFullMessage
            : 'Mancano uno o più allegati della copia. Scegli un’altra copia.',
      );
    }
    final sicurezza = await snapshot(motivo: BackupReason.preRipristino);
    _database.ripristinaDa(file);
    return sicurezza;
  }
}

Future<BackupFile> _ripristinaDaFileEsterno(
  String percorso,
  Future<BackupFile> Function(File file) applica,
) async {
  final temporanea = await Directory.systemTemp.createTemp('planner-copia-');
  try {
    final file = await File(percorso).copy(p.join(temporanea.path, 'copia.db'));
    final esito = await verificaCopia(file);
    if (!esito.ok) {
      throw BackupFallito('Il file è danneggiato o non è una copia di Acta.');
    }
    const campi = {
      'events': {'id', 'title', 'start_time', 'end_time'},
      'todos': {'id', 'title', 'completed'},
      'notes': {'id', 'title', 'content'},
    };
    final copia = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      if (readSchemaVersion(copia) > schemaVersion) {
        throw BackupFallito('Aggiorna Acta per aprire questa copia.');
      }
      for (final entry in campi.entries) {
        final colonne = copia
            .select('SELECT name FROM pragma_table_info(?)', [entry.key])
            .map((riga) => riga['name'])
            .toSet();
        if (!colonne.containsAll(entry.value) ||
            !esito.conteggi.containsKey(entry.key)) {
          throw BackupFallito('Il file non è una copia di Acta.');
        }
      }
    } finally {
      copia.dispose();
    }
    return await applica(file);
  } finally {
    await temporanea.delete(recursive: true);
  }
}
