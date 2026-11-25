import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/domain/event_occurrence.dart';
import 'package:planner/features/filters/filtro_condiviso.dart';
import 'package:planner/features/filters/filtro_condiviso_controller.dart';
import 'package:planner/features/todos/domain/todo.dart';

/// Il filtro condiviso: cosa fa passare, cosa no, e cosa ricorda fra un avvio e
/// l'altro.
void main() {
  final giorno = DateTime(2026, 9, 14, 9);

  EventOccurrence occorrenza(List<String> categorie) {
    final event = Event(
      id: 'e',
      title: 'Evento',
      start: giorno,
      end: giorno.add(const Duration(hours: 1)),
      categoryIds: categorie,
    );
    return EventOccurrence(
        event: event,
        date: giorno,
        start: giorno,
        end: giorno.add(const Duration(hours: 1)));
  }

  Todo todo(List<String> categorie) =>
      Todo(id: 't', title: 'Todo', categoryIds: categorie);

  group('regole', () {
    test('di partenza non vincola niente', () {
      const filtro = FiltroCondiviso();

      expect(filtro.isEmpty, isTrue);
      expect(filtro.giorni, 30, reason: "l'orizzonte di partenza");
      expect(filtro.passaEvento(occorrenza(const [])), isTrue);
      expect(filtro.passaTodo(todo(const [])), isTrue);
    });

    test('con una categoria scelta passa solo chi ce l\'ha', () {
      const filtro = FiltroCondiviso(categorieScelte: {'lavoro'});

      expect(filtro.passaEvento(occorrenza(const ['lavoro'])), isTrue);
      expect(filtro.passaEvento(occorrenza(const ['casa'])), isFalse);
      // Chi non ha nessuna categoria non passa: e' la stessa regola del filtro
      // dei todo, e con almeno una categoria scelta "senza etichetta" non e'
      // una delle cose che si stanno guardando.
      expect(filtro.passaEvento(occorrenza(const [])), isFalse);

      expect(filtro.passaTodo(todo(const ['lavoro', 'casa'])), isTrue);
      expect(filtro.passaTodo(todo(const ['casa'])), isFalse);
      expect(filtro.passaTodo(todo(const [])), isFalse);
    });

    test('«cosa mostrare» decide quali delle due famiglie passano', () {
      expect(
        const FiltroCondiviso(cosa: CosaMostrare.eventi)
            .passaTodo(todo(const [])),
        isFalse,
      );
      expect(
        const FiltroCondiviso(cosa: CosaMostrare.eventi)
            .passaEvento(occorrenza(const [])),
        isTrue,
      );

      expect(
        const FiltroCondiviso(cosa: CosaMostrare.todo)
            .passaEvento(occorrenza(const [])),
        isFalse,
      );
      expect(
        const FiltroCondiviso(cosa: CosaMostrare.todo)
            .passaTodo(todo(const [])),
        isTrue,
      );

      const entrambi = FiltroCondiviso(cosa: CosaMostrare.entrambi);
      expect(entrambi.passaEvento(occorrenza(const [])), isTrue);
      expect(entrambi.passaTodo(todo(const [])), isTrue);
    });

    test('i tre orizzonti sono 7, 30 e 90 giorni', () {
      expect(
        const FiltroCondiviso(orizzonte: Orizzonte.giorni7).giorni,
        7,
      );
      expect(
        const FiltroCondiviso(orizzonte: Orizzonte.giorni30).giorni,
        30,
      );
      expect(
        const FiltroCondiviso(orizzonte: Orizzonte.giorni90).giorni,
        90,
      );
    });

    test('la firma cambia quando cambia il filtro, e non a caso', () {
      const base = FiltroCondiviso();
      expect(base.firma, const FiltroCondiviso().firma, reason: 'stabile');

      expect(
        base.copyWith(categorieScelte: const {'lavoro'}).firma,
        isNot(base.firma),
      );
      // Due insiemi scritti in ordine diverso sono lo stesso filtro: se la firma
      // li distinguesse, la memoria delle viste si invaliderebbe per niente.
      expect(
        base.copyWith(categorieScelte: const {'a', 'b'}).firma,
        base.copyWith(categorieScelte: const {'b', 'a'}).firma,
      );
      expect(
        base.copyWith(cosa: CosaMostrare.todo).firma,
        isNot(base.firma),
      );
      expect(
        base.copyWith(orizzonte: Orizzonte.giorni7).firma,
        isNot(base.firma),
      );
    });
  });

  group('persistenza', () {
    late DatabaseService db;
    late FiltroCondivisoController controller;

    setUp(() async {
      db = DatabaseService();
      await db.init(dbPath: ':memory:');
      controller = FiltroCondivisoController(db.settings)..load();
    });

    tearDown(() => db.close());

    test('le scelte sopravvivono a un nuovo avvio', () async {
      controller.toggleCategoria('lavoro');
      controller.toggleCategoria('casa');
      controller.toggleCategoria('casa');
      controller.setCosa(CosaMostrare.eventi);
      controller.setOrizzonte(Orizzonte.giorni90);

      // La scrittura passa da una microattivita' (e' fuori dal fotogramma del
      // gesto): senza cedere il turno, il nuovo avvio leggerebbe il vuoto.
      await Future<void>.delayed(Duration.zero);

      final riletto = FiltroCondivisoController(db.settings)..load();

      expect(riletto.filtro.categorieScelte, {'lavoro'});
      expect(riletto.filtro.cosa, CosaMostrare.eventi);
      expect(riletto.filtro.orizzonte, Orizzonte.giorni90);
      expect(riletto.isDefault, isFalse);
    });

    test('azzera riporta al default e toglie le chiavi', () async {
      controller.toggleCategoria('lavoro');
      controller.setOrizzonte(Orizzonte.giorni7);
      controller.reset();
      await Future<void>.delayed(Duration.zero);

      expect(controller.isDefault, isTrue);
      expect(db.settings.get('filtroCondivisoCategorie'), isNull);
      expect(db.settings.get('filtroCondivisoCosa'), isNull);
      expect(db.settings.get('filtroCondivisoOrizzonte'), isNull);
    });

    test('un valore rotto non svuota l\'agenda', () {
      db.settings.set('filtroCondivisoCosa', 'qualcosa');
      db.settings.set('filtroCondivisoOrizzonte', 'perSempre');
      db.settings.set('filtroCondivisoCategorie', ' lavoro ,, casa ');

      final riletto = FiltroCondivisoController(db.settings)..load();

      expect(riletto.filtro.cosa, CosaMostrare.entrambi);
      expect(riletto.filtro.orizzonte, Orizzonte.giorni30);
      expect(riletto.filtro.categorieScelte, {'lavoro', 'casa'});
    });
  });
}
