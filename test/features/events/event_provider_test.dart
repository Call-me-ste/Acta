import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/domain/event.dart';
import 'package:planner/features/events/event_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// La stessa tabella, ma conta le letture complete: è l'unico modo per affermare
/// "non rilegge tutto a ogni scrittura" **senza** un cronometro (i millisecondi
/// in un test non sono una prova: una macchina carica li muove).
class _DbContata extends DatabaseService {
  int lettureTotali = 0;

  @override
  List<Row> getEvents() {
    lettureTotali++;
    return super.getEvents();
  }
}

void main() {
  late DatabaseService db;
  late EventProvider provider;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    provider = EventProvider(db);
  });

  tearDown(() => db.close());

  test('addEvent genera id uuid e il modello legge i tipi giusti', () async {
    await provider.addEvent(
      title: 'Dentista',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
      colorIndex: 2,
    );
    await provider.addEvent(
      title: 'Palestra',
      start: DateTime(2026, 9, 14, 18),
      end: DateTime(2026, 9, 14, 19),
    );

    expect(provider.events, hasLength(2));
    // uuid v4, non millisecondi: due item creati nello stesso istante non
    // possono più collidere.
    expect(provider.events.map((e) => e.id).toSet(), hasLength(2));

    final dentista = provider.events.firstWhere((e) => e.title == 'Dentista');
    expect(dentista.allDay, isFalse); // bool, non int
    expect(dentista.colorIndex, 2);
    expect(dentista.start, DateTime(2026, 9, 14, 9));
    expect(dentista.end, DateTime(2026, 9, 14, 10));
  });

  test('occurrencesForDate restituisce solo il giorno richiesto', () async {
    await provider.addEvent(
      title: 'oggi',
      start: DateTime(2026, 9, 13, 9),
      end: DateTime(2026, 9, 13, 10),
    );
    await provider.addEvent(
      title: 'domani',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    );

    expect(
      provider.occurrencesForDate(DateTime(2026, 9, 13)).map((e) => e.title),
      ['oggi'],
    );
    expect(
      provider.occurrencesForDate(DateTime(2026, 9, 14)).map((e) => e.title),
      ['domani'],
    );
    expect(provider.occurrencesForDate(DateTime(2026, 9, 15)), isEmpty);
  });

  test('updateEvent persiste anche i booleani, deleteEvent rimuove', () async {
    await provider.addEvent(
      title: 'Bozza',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    );
    final bozza = provider.events.single;

    await provider.updateEvent(
      Event(
        id: bozza.id,
        title: 'Definitivo',
        start: DateTime(2026, 9, 14, 11),
        end: DateTime(2026, 9, 14, 12),
        allDay: true,
        colorIndex: 4,
      ),
    );

    final updated = provider.events.single;
    expect(updated.title, 'Definitivo');
    expect(updated.start, DateTime(2026, 9, 14, 11));
    expect(updated.colorIndex, 4);
    // Regressione: un bool passato a SQLite non è un tipo valido. Con il modello
    // tipato `toParams()` manda 1, e la rilettura torna `true`.
    expect(updated.allDay, isTrue);

    await provider.deleteEvent(bozza.id);
    expect(provider.events, isEmpty);
  });

  test('toParams manda 0/1 per i booleani, mai un bool', () {
    final params = Event(
      id: 'x',
      title: 't',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    ).toParams();

    expect(params['all_day'], 0);
    expect(params['all_day'], isA<int>());
    expect(
        params['start_time'], DateTime(2026, 9, 14, 9).millisecondsSinceEpoch);
  });

  test('salvare non rilegge tutto l\'archivio', () async {
    final contata = _DbContata();
    await contata.init(dbPath: ':memory:');
    addTearDown(contata.close);
    final conConto = EventProvider(contata);

    // Costruire il provider non legge niente: la tabella si legge alla prima
    // richiesta. Con un archivio lungo, l'apertura dell'app non lo paga.
    expect(contata.lettureTotali, 0);

    await conConto.addEvent(
      title: 'uno',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    );
    // La scrittura non rilegge: è quello che prima succedeva a ogni tocco.
    expect(contata.lettureTotali, 0);

    // La lettura si paga **una** volta, e la seconda volta si riusa.
    expect(conConto.events.single.title, 'uno');
    expect(conConto.events, hasLength(1));
    expect(contata.lettureTotali, 1);

    await conConto.updateEvent(
      conConto.events.single.copyWith(title: 'uno (spostato)'),
    );
    expect(contata.lettureTotali, 1);
    // Dopo una scrittura la copia in memoria non vale più: la lettura successiva
    // rilegge (una volta sola) e vede la modifica.
    expect(conConto.events.single.title, 'uno (spostato)');
    expect(contata.lettureTotali, 2);
  });
}
