/// Le **categorie di default**: otto etichette che esistono appena si apre l'app.
///
/// Perché: una pagina «Categorie» vuota è un compito a casa. L'utente dovrebbe
/// decidere *prima* di usare l'app come si chiamano le proprie etichette, e chi
/// non ha voglia non ne crea nessuna — quindi non le usa mai. I calendari grandi
/// fanno la stessa cosa (Apple ha le sue liste «Casa» e «Lavoro», Outlook parte
/// con le categorie per colore, Microsoft To Do con la lista «Attività»): il
/// punto è non lasciare il primo avvio davanti al vuoto.
///
/// Le otto sono **un'ipotesi**, non una gabbia: si rinominano, si ricolorano e si
/// eliminano come tutte le altre (l'editor c'è già), e chi non ne vuole nessuna
/// le toglie in otto tocchi.
///
/// **Gli id sono fissi** (`cat-suggerita-casa`, …) e non casuali: due device che
/// seminano prima di essersi mai sincronizzati scrivono le **stesse** righe, e il
/// sync non trova due «Casa» da fondere.
library;

import '../../core/database/database_service.dart';
import 'category_repair.dart';
import 'domain/category.dart';

/// La chiave in `app_settings` che dice «il seme è già stato fatto».
///
/// Perché serve, visto che basta guardare se la libreria è vuota: perché **non**
/// basta. Chi cancella tutte le categorie (perché non ne vuole) se le vedrebbe
/// ricomparire al riavvio — un'app che rimette quello che hai tolto è un'app che
/// non si controlla. La chiave si scrive **sempre**, anche quando non c'è niente
/// da seminare, così non ci si riprova.
const String chiaveCategorieSuggerite = 'categorieSuggerite';

/// Le otto categorie suggerite: nome, emoji, colore.
///
/// I colori sono **fissi** e non presi dalla palette attiva, come quelli delle
/// priorità: «Salute è verde» deve restare vero anche cambiando tema, se no le
/// etichette diventano otto colori casuali. Sono tinte scure abbastanza da
/// leggersi su chiaro e su scuro.
const List<({String id, String nome, String emoji, String colore})>
    categorieSuggerite = [
  (id: 'cat-suggerita-casa', nome: 'Casa', emoji: '🏠', colore: '#C2410C'),
  (id: 'cat-suggerita-lavoro', nome: 'Lavoro', emoji: '💼', colore: '#1D4ED8'),
  (id: 'cat-suggerita-studio', nome: 'Studio', emoji: '🎓', colore: '#7C3AED'),
  (id: 'cat-suggerita-salute', nome: 'Salute', emoji: '💚', colore: '#059669'),
  (
    id: 'cat-suggerita-famiglia',
    nome: 'Famiglia',
    emoji: '👨‍👩‍👧',
    colore: '#DB2777'
  ),
  (id: 'cat-suggerita-sport', nome: 'Sport', emoji: '🏃', colore: '#0891B2'),
  (
    id: 'cat-suggerita-tempo-libero',
    nome: 'Tempo libero',
    emoji: '🎉',
    colore: '#CA8A04'
  ),
  (id: 'cat-suggerita-viaggi', nome: 'Viaggi', emoji: '✈️', colore: '#4B5563'),
];

/// Scrive le categorie suggerite se — e solo se — servono. Torna quante ne ha
/// scritte (0 = niente da fare).
///
/// Le tre condizioni, in ordine di costo:
///
/// 1. la chiave dice che il seme è già stato fatto → non si fa niente (è il
///    caso normale: dopo il primo avvio si esce alla prima riga);
/// 2. la libreria **non** è vuota → si marca la chiave e non si semina: chi ha
///    già le sue categorie (o le ha appena prese da un altro device) non deve
///    trovarsi otto estranee in mezzo;
/// 3. libreria vuota e chiave mai scritta → si seminano le otto.
///
/// Ogni riga entra nell'**outbox** come tutte le altre (la libreria delle
/// categorie viaggia fra i device), e scritta e accodata stanno nella stessa
/// transazione: o parte tutto, o non parte niente.
int seminaCategorieSuggerite(DatabaseService db) {
  if (db.settings.get(chiaveCategorieSuggerite) == '1') return 0;

  if (db.categories.all().isNotEmpty) {
    db.settings.set(chiaveCategorieSuggerite, '1');
    return 0;
  }

  final adesso = DateTime.now();
  db.runInTransaction(() {
    for (final voce in categorieSuggerite) {
      final categoria = ItemCategory(
        id: voce.id,
        name: voce.nome,
        emoji: voce.emoji,
        colorHex: voce.colore,
        updatedAt: adesso,
      );
      final params = categoria.toParams();

      db.categories.upsert(params);
      enqueueCategoryOperation(
        db,
        entityId: categoria.id,
        operation: 'upsert',
        version: categoria.version,
        updatedAt: adesso,
        payload: params,
      );
    }
    db.settings.set(chiaveCategorieSuggerite, '1');
  });

  return categorieSuggerite.length;
}
