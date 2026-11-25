/// Dove finiscono gli shard.
///
/// L'interfaccia è volutamente minima — elenca, leggi, scrivi, cancella — così
/// la stessa logica di sync funziona su una cartella locale (e nei test) e su
/// Google Drive AppData: **cambia solo l'implementazione**, non il codice che
/// la usa.
abstract interface class SyncGateway {
  /// Percorsi sotto `prefix` (stringa vuota = tutto). Separatore `/`, sempre
  /// relativi alla radice del gateway.
  Future<List<String>> list(String prefix);

  /// `null` se il percorso non esiste: assenza non è errore.
  Future<List<int>?> read(String path);

  Future<void> write(String path, List<int> bytes);

  Future<void> delete(String path);
}
