import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/categories/category_seed.dart';
import 'package:planner/features/categories/domain/category.dart';

/// Le **categorie di default**: otto etichette seminate una volta sola, e solo su
/// una libreria vuota.
///
/// Perché conta: la pagina Categorie vuota è il primo avvio di chi non ha voglia
/// di impostare niente — ed è anche il caso in cui si decide se l'app si userà
/// mai. Le tre cose che non devono succedere: seminarle **due volte**, seminarle
/// **sopra** categorie che l'utente ha già, e rimetterle dopo che le ha
/// cancellate.
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() => db.close());

  test('su una libreria vuota semina le otto, e le accoda per il sync',
      () async {
    final seminate = seminaCategorieSuggerite(db);

    expect(seminate, categorieSuggerite.length);
    final righe = db.categories.all().map(ItemCategory.fromRow).toList();
    expect(righe, hasLength(8));
    for (final voce in categorieSuggerite) {
      final trovata = righe.firstWhere((c) => c.id == voce.id);
      expect(trovata.name, voce.nome);
      expect(trovata.emoji, voce.emoji);
      expect(trovata.colorHex, voce.colore);
    }

    // Le categorie **viaggiano** fra i device: se nascono qui e basta, l'altro
    // device le ri-seminerebbe (o non le vedrebbe mai).
    expect(db.outbox.pending(), hasLength(8),
        reason: 'ogni categoria seminata accoda la sua operazione');

    // E il controller le trova già dentro: la pagina Categorie non mostra il
    // vuoto al primo avvio.
    final controller = CategoryController(db);
    expect(controller.all, hasLength(8));
  });

  test('la seconda volta non fa niente, e non riaccoda', () async {
    seminaCategorieSuggerite(db);
    final dopo = db.outbox.pending().length;

    expect(seminaCategorieSuggerite(db), 0);
    expect(db.categories.all(), hasLength(8));
    expect(db.outbox.pending(), hasLength(dopo),
        reason: 'niente righe nuove in coda: non è una scrittura');
  });

  test('non tocca una libreria che ha già qualcosa dentro', () async {
    db.categories.upsert(
      const ItemCategory(id: 'mia', name: 'Mia', emoji: '⭐').toParams(),
    );

    expect(seminaCategorieSuggerite(db), 0,
        reason: 'chi ha già le sue categorie non si trova otto estranee');

    final righe = db.categories.all().map(ItemCategory.fromRow).toList();
    expect(righe, hasLength(1));
    expect(righe.single.name, 'Mia');
    expect(db.settings.get(chiaveCategorieSuggerite), '1',
        reason: 'la chiave si scrive lo stesso: non si riprova a ogni avvio');
  });

  test('non risemina dopo che l\'utente le ha cancellate tutte', () async {
    seminaCategorieSuggerite(db);
    for (final voce in categorieSuggerite) {
      db.categories.delete(voce.id);
    }
    expect(db.categories.all(), isEmpty);

    expect(seminaCategorieSuggerite(db), 0,
        reason: 'un\'app che rimette quello che hai tolto non si controlla');
    expect(db.categories.all(), isEmpty);
  });
}
