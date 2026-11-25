import 'database_service.dart';
import 'occurrence_store.dart';

/// L'unico modo di **confermare un'occorrenza**: «questo evento di martedì l'ho
/// fatto».
///
/// Vale sia per un evento sia per un todo, perché la tabella delle eccezioni è la
/// stessa — e così la conferma entra nel sync come qualsiasi altra entità, senza
/// codice nuovo.
///
/// Sta fuori da `database_service.dart` (che ha un budget di 300 righe e gia' fa
/// il ciclo di vita della connessione, le transazioni e le due tabelle principali)
/// e vive accanto a `OccurrenceStore`, che e' chi sa come sono fatte le chiavi.
extension ConfermeDiOccorrenza on DatabaseService {
  static const String _entity = 'occurrence_override';

  /// Segna **una** occorrenza come fatta.
  ///
  /// Il clock (`version`) avanza come per le altre entità: è quello che il sync
  /// confronta fra due dispositivi. La scrittura della riga e quella della voce
  /// in outbox stanno nella stessa transazione: o partono insieme, o non parte
  /// niente.
  void markOccurrenceDone({
    required String itemId,
    required DateTime day,
    required String operationId,
  }) {
    runInTransaction(() => markOccurrenceDoneInTransaction(
          itemId: itemId,
          day: day,
          operationId: operationId,
        ));
  }

  /// Riusa la transazione del chiamante quando ci sono altre scritture atomiche.
  void markOccurrenceDoneInTransaction({
    required String itemId,
    required DateTime day,
    required String operationId,
  }) {
    final key = OccurrenceStore.keyFor(itemId, day);
    final now = DateTime.now();
    final version = occurrences.currentVersion(itemId, day) + 1;
    final params = <String, Object?>{
      'id': key,
      'item_id': itemId,
      'occurrence_date': OccurrenceStore.dayMillis(day),
      'state': 'done',
      'version': version,
      'updated_at': now.millisecondsSinceEpoch,
    };

    entities.replace(_entity, key, params);
    outbox.enqueue(
      operationId: operationId,
      entity: _entity,
      entityId: key,
      operation: 'upsert',
      version: version,
      updatedAt: now.millisecondsSinceEpoch,
      payload: params,
    );
  }
}
