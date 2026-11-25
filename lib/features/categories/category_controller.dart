// Solo ChangeNotifier: `foundation` esporta anche una `Category` sua,
// e il nostro modello si chiama ItemCategory per non scontrarsi.
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:uuid/uuid.dart';

import '../../core/categories/category_ids.dart';
import '../../core/database/database_service.dart';
import 'category_repair.dart';
import 'domain/category.dart';

/// Le categorie: creare, rinominare, ricolorare, eliminare.
///
/// Ogni scrittura accoda la sua operazione in outbox nella stessa transazione e
/// avanza il clock, come le palette: la libreria **viaggia** fra i device.
///
/// Eliminare una categoria **non** cancella gli elementi che la usano: sparisce
/// l'etichetta, non il contenuto. Le righe toccate si riscrivono col nuovo
/// `category_ids` e si accodano, cosi' anche l'altro dispositivo le vede senza
/// quella categoria.
class CategoryController extends ChangeNotifier {
  CategoryController(this._db) {
    load();
    // Due riparazioni una-tantum, idempotenti (vedi category_repair.dart): la
    // vecchia colonna di testo libero dei todo e i doppioni creati prima che la
    // regola esistesse.
    final repair = CategoryRepair(_db);
    // La conversione puo' **aggiungere** categorie: si rilegge prima di unire,
    // altrimenti la fusione lavorerebbe su un elenco vecchio e non vedrebbe
    // quelle appena nate.
    if (repair.migrateLegacyColumn() > 0) load();
    final unite = repair.mergeDuplicates([
      for (final category in _categories)
        ItemCategoryLike(
          id: category.id,
          key: keyOf(category.name, category.emoji),
          version: category.version,
        ),
    ]);
    if (unite > 0) load();
  }

  final DatabaseService _db;
  static const _uuid = Uuid();
  static const String _entity = 'category';

  List<ItemCategory> _categories = [];

  List<ItemCategory> get all => _categories;

  ItemCategory? byId(String id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// Le categorie di un elemento, **nell'ordine** in cui sono state scelte e
  /// senza quelle che non esistono piu': un id sconosciuto si ignora, perche'
  /// puo' essere una categoria cancellata su un altro dispositivo.
  List<ItemCategory> byIds(List<String> ids) {
    final found = <ItemCategory>[];
    for (final id in ids) {
      final category = byId(id);
      if (category != null) found.add(category);
    }
    return found;
  }

  /// La categoria con quel nome, se c'e' (senza badare a maiuscole): serve a
  /// non creare doppioni quando si scrive il nome a mano.
  ItemCategory? byName(String name) {
    final clean = name.trim().toLowerCase();
    if (clean.isEmpty) return null;
    for (final category in _categories) {
      if (category.name.toLowerCase() == clean) return category;
    }
    return null;
  }

  void load() {
    _categories = _db.categories.all().map(ItemCategory.fromRow).toList();
    notifyListeners();
  }

  /// La chiave di confronto fra due categorie: il nome senza badare a maiuscole
  /// e spazi (in testa, in coda, doppi) **piu' l'emoji**.
  ///
  /// L'emoji fa parte della chiave di proposito: "Lavoro" con la valigetta e
  /// "Lavoro" con la casa sono due categorie diverse, ed e' cosi' che si
  /// distinguono due cose che si chiamano uguale.
  static String keyOf(String name, String emoji) {
    final pulito = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return '$pulito\u0000${emoji.trim()}';
  }

  /// La categoria che ha **gia'** questo nome e questa emoji, se c'e'.
  ///
  /// La regola vive qui e non nell'interfaccia: creare una categoria deve
  /// restare un'operazione sola, da qualunque punto la si chiami, e un domani
  /// la stessa regola serve anche a chi importa un backup.
  ItemCategory? duplicateOf(String name, String emoji, {String? exceptId}) {
    final chiave = keyOf(name, emoji);
    for (final category in _categories) {
      if (category.id == exceptId) continue;
      if (keyOf(category.name, category.emoji) == chiave) return category;
    }
    return null;
  }

  Future<ItemCategory> create({
    required String name,
    String emoji = '',
    String colorHex = '',
  }) async {
    // Un doppione non si crea: si usa quello che c'e' gia'. Cosi' "Lavoro",
    // "LAVORO" e "LaVoRO" con la stessa emoji restano una categoria sola, e chi
    // scrive non si trova due voci uguali nell'elenco.
    final esistente = duplicateOf(name, emoji);
    if (esistente != null) return esistente;

    final category = ItemCategory(
      id: _uuid.v4(),
      name: name.trim(),
      emoji: emoji,
      colorHex: colorHex,
      updatedAt: DateTime.now(),
    );
    await save(category);
    return category;
  }

  /// Salva una categoria nuova o modificata. Avanza il clock, come ogni altra
  /// scrittura: e' quello che il sync confronta.
  ///
  /// Torna `false` se nome ed emoji sono gia' di un'**altra** categoria: chi
  /// chiama lo dice all'utente, invece di fondere due etichette di nascosto (la
  /// fusione dei doppioni gia' esistenti la fa [mergeDuplicates] all'avvio).
  Future<bool> save(ItemCategory category) async {
    if (duplicateOf(category.name, category.emoji, exceptId: category.id) !=
        null) {
      return false;
    }

    final next = category.copyWith(
      version: category.version + 1,
      updatedAt: DateTime.now(),
    );

    _db.runInTransaction(() {
      _db.categories.upsert(next.toParams());
      enqueueCategoryOperation(
        _db,
        entityId: next.id,
        operation: 'upsert',
        version: next.version,
        updatedAt: next.updatedAt!,
        payload: next.toParams(),
      );
    });
    load();
    return true;
  }

  /// Quanti elementi usano questa categoria. La conferma di eliminazione lo
  /// dice: "la usano 12 elementi" e' una decisione diversa da "non la usa
  /// nessuno".
  int usageCount(String id) => _db.categories.itemsUsing(id).length;

  Future<void> remove(String id) async {
    final category = byId(id);
    if (category == null) return;

    final now = DateTime.now();
    final affected = _db.categories.itemsUsing(id);

    _db.runInTransaction(() {
      for (final item in affected) {
        final clock = _db.entities.localClock(item.entity, item.id);
        final version = (clock?.$1 ?? 1) + 1;

        _db.categories.setItemCategoryIds(
          table: item.table,
          id: item.id,
          encoded: encodeCategoryIds(
            item.ids.where((other) => other != id).toList(),
          ),
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

      final clock = _db.entities.localClock(_entity, id);
      _db.categories.delete(id);
      enqueueCategoryOperation(
        _db,
        entityId: id,
        operation: 'delete',
        // La cancellazione ha una versione piu' alta della riga: cosi' vince su
        // un aggiornamento piu' vecchio che arrivasse da un altro device.
        version: (clock?.$1 ?? category.version) + 1,
        updatedAt: now,
        payload: const {},
      );
    });
    load();
  }
}
