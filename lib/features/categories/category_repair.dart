import 'package:uuid/uuid.dart';

import '../../core/categories/category_ids.dart';
import '../../core/database/database_service.dart';

/// Accoda un'operazione di sync per la libreria delle categorie.
///
/// L'`operationId` si genera qui dentro, cosi' nessuno puo' dimenticarselo, e la
/// usano sia il controller (salvataggi e cancellazioni) sia le riparazioni
/// all'avvio, che stanno in questo file.
void enqueueCategoryOperation(
  DatabaseService db, {
  String entity = 'category',
  required String entityId,
  required String operation,
  required int version,
  required DateTime updatedAt,
  required Map<String, Object?> payload,
}) {
  db.outbox.enqueue(
    operationId: const Uuid().v4(),
    entity: entity,
    entityId: entityId,
    operation: operation,
    version: version,
    updatedAt: updatedAt.millisecondsSinceEpoch,
    payload: payload,
  );
}

/// Le due riparazioni **una-tantum** della libreria delle categorie.
///
/// Girano a ogni avvio, ma entrambe sono idempotenti: la prima volta mettono a
/// posto quello che c'e' da mettere a posto, dal secondo giro non trovano piu'
/// niente. Stanno fuori dal controller perche' non sono "cosa fa una categoria",
/// sono "cosa si sistema una volta sola" — e perche' il controller ha un budget
/// di righe da rispettare (`test/architecture_test.dart`).
class CategoryRepair {
  CategoryRepair(this._db);

  final DatabaseService _db;
  static const String _entity = 'category';

  /// La vecchia colonna `todos.category` (testo libero, mai vista
  /// nell'interfaccia: un avanzo delle prime versioni) diventa una categoria
  /// vera, cosi' chi l'aveva riempita non perde niente.
  ///
  /// Idempotente: dopo la conversione la colonna si svuota, quindi al secondo
  /// avvio non c'e' piu' niente da fare e non serve una chiave che ricordi
  /// "gia' fatto". Torna quanti todo ha convertito.
  int migrateLegacyColumn() {
    final rows = _db.categories.legacyTodoRows();
    if (rows.isEmpty) return 0;

    final now = DateTime.now();
    var converted = 0;

    _db.runInTransaction(() {
      for (final row in rows) {
        final name = ((row['category'] as String?) ?? '').trim();
        final todoId = row['id'] as String;
        if (name.isEmpty) continue;

        final existing = _db.categories.byName(name);
        final categoryId =
            existing == null ? const Uuid().v4() : existing['id'] as String;
        if (existing == null) {
          _db.categories.upsert({
            'id': categoryId,
            'name': name,
            'emoji': '',
            'color_hex': '',
            'version': 1,
            'updated_at': now.millisecondsSinceEpoch,
          });
          enqueueCategoryOperation(
            _db,
            entityId: categoryId,
            operation: 'upsert',
            version: 1,
            updatedAt: now,
            payload: {
              'id': categoryId,
              'name': name,
              'emoji': '',
              'color_hex': '',
              'version': 1,
              'updated_at': now.millisecondsSinceEpoch,
            },
          );
        }

        final clock = _db.entities.localClock('todo', todoId);
        final version = (clock?.$1 ?? 1) + 1;
        _db.categories.setItemCategoryIds(
          table: 'todos',
          id: todoId,
          encoded: encodeCategoryIds([categoryId]),
          version: version,
          updatedAt: now,
        );
        _db.categories.clearLegacyCategory('todos', todoId);

        final updated = _db.categories.rowOf('todos', todoId);
        if (updated == null) continue;
        enqueueCategoryOperation(
          _db,
          entity: 'todo',
          entityId: todoId,
          operation: 'upsert',
          version: version,
          updatedAt: now,
          payload: updated,
        );
        converted++;
      }
    });

    return converted;
  }

  /// Unisce le categorie che sono la **stessa cosa** (stesso nome a meno di
  /// maiuscole e spazi, stessa emoji) e riporta alla prima gli elementi che
  /// puntavano alle altre.
  ///
  /// Serve per i doppioni creati prima che la regola esistesse. Torna quante ne
  /// ha unite.
  int mergeDuplicates(List<ItemCategoryLike> categories) {
    final tenute = <String, ItemCategoryLike>{};
    final vittime = <ItemCategoryLike>[];
    for (final category in categories) {
      final chiave = category.key;
      if (tenute.containsKey(chiave)) {
        vittime.add(category);
      } else {
        tenute[chiave] = category;
      }
    }
    if (vittime.isEmpty) return 0;

    final now = DateTime.now();
    _db.runInTransaction(() {
      for (final vittima in vittime) {
        final tenuta = tenute[vittima.key]!;

        for (final item in _db.categories.itemsUsing(vittima.id)) {
          final clock = _db.entities.localClock(item.entity, item.id);
          final version = (clock?.$1 ?? 1) + 1;
          _db.categories.setItemCategoryIds(
            table: item.table,
            id: item.id,
            encoded: encodeCategoryIds([
              for (final id in item.ids)
                id == vittima.id ? tenuta.id : id,
            ]),
            version: version,
            updatedAt: now,
          );
          final row = _db.categories.rowOf(item.table, item.id);
          if (row == null) continue;
          enqueueCategoryOperation(
            _db,
            entity: item.entity,
            entityId: item.id,
            operation: 'upsert',
            version: version,
            updatedAt: now,
            payload: row,
          );
        }

        final clock = _db.entities.localClock(_entity, vittima.id);
        _db.categories.delete(vittima.id);
        enqueueCategoryOperation(
          _db,
          entityId: vittima.id,
          operation: 'delete',
          version: (clock?.$1 ?? vittima.version) + 1,
          updatedAt: now,
          payload: const {},
        );
      }
    });

    return vittime.length;
  }
}

/// Quello che alla fusione serve sapere di una categoria: id, versione e la
/// chiave di confronto. Il controller passa i suoi `ItemCategory`, la fusione
/// non ha bisogno di sapere nient'altro.
class ItemCategoryLike {
  const ItemCategoryLike({
    required this.id,
    required this.key,
    this.version = 1,
  });

  final String id;
  final String key;
  final int version;
}
