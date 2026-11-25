import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/events/event_provider.dart';

/// La prova che il bug della v2 non può tornare.
///
/// In v2 la lista espansa conteneva **anche il template** della serie, dentro
/// viste a sezioni per giorno (`Oggi`, `Domani`, …): il risultato era un item
/// ricorrente che compariva in ogni giorno. Qui la regola è una sola — una vista
/// raggruppa e ordina per la **data dell'occorrenza** — e questi test contano le
/// voci per dimostrarlo.
void main() {
  late DatabaseService db;
  late EventProvider provider;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    provider = EventProvider(db);
  });

  tearDown(() => db.close());

  test('una serie compare una volta per giorno, non in ogni giorno', () async {
    // 2026-09-14 è un lunedì.
    await provider.addEvent(
      title: 'Palestra',
      start: DateTime(2026, 9, 14, 18),
      end: DateTime(2026, 9, 14, 19),
      recurrenceRule: 'FREQ=DAILY',
    );

    final window = provider.occurrencesBetween(
      DateTime(2026, 9, 14),
      DateTime(2026, 9, 17),
    );

    expect(window, hasLength(3), reason: 'tre giorni, tre voci');
    expect(
      window.map((occurrence) => occurrence.date),
      [DateTime(2026, 9, 14), DateTime(2026, 9, 15), DateTime(2026, 9, 16)],
    );
    // Ora e durata restano quelle del template.
    expect(window.first.start, DateTime(2026, 9, 14, 18));
    expect(window.last.start, DateTime(2026, 9, 16, 18));
    expect(window.last.end, DateTime(2026, 9, 16, 19));
  });

  test('lun-ven non compare nel fine settimana', () async {
    await provider.addEvent(
      title: 'Ufficio',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 18),
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
    );

    // Sabato e domenica non devono contenere niente.
    expect(provider.occurrencesForDate(DateTime(2026, 9, 19)), isEmpty);
    expect(provider.occurrencesForDate(DateTime(2026, 9, 20)), isEmpty);
    expect(provider.occurrencesForDate(DateTime(2026, 9, 21)), hasLength(1));
  });

  test('il giorno mostra le sue occorrenze, e solo le sue', () async {
    await provider.addEvent(
      title: 'Una volta',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
    );
    await provider.addEvent(
      title: 'Ogni giorno',
      start: DateTime(2026, 9, 14, 18),
      end: DateTime(2026, 9, 14, 19),
      recurrenceRule: 'FREQ=DAILY',
    );

    // Ordinati per ora di inizio: l'evento singolo e la sua occorrenza.
    expect(
      provider.occurrencesForDate(DateTime(2026, 9, 14)).map((o) => o.title),
      ['Una volta', 'Ogni giorno'],
    );
    // Il giorno dopo resta **solo** la serie: l'evento singolo non si trascina.
    expect(
      provider.occurrencesForDate(DateTime(2026, 9, 15)).map((o) => o.title),
      ['Ogni giorno'],
    );
    expect(provider.occurrencesForDate(DateTime(2026, 9, 16)), hasLength(1));
  });

  test('il template non viene mai mostrato come sé stesso', () async {
    await provider.addEvent(
      title: 'Serie',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO',
    );

    // La data del template è il 14, ma la finestra parte dal 21: la voce che si
    // vede è l'occorrenza del 21, non il template rimasto al 14.
    final window = provider.occurrencesBetween(
      DateTime(2026, 9, 21),
      DateTime(2026, 9, 22),
    );
    expect(window, hasLength(1));
    expect(window.single.date, DateTime(2026, 9, 21));
  });

  test('una regola illeggibile non fa sparire l\'evento', () async {
    await provider.addEvent(
      title: 'Rotta',
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 10),
      recurrenceRule: 'QUALCOSA_DI_STRANO',
    );

    // Meglio mostrarlo come evento singolo che perderlo da ogni vista.
    expect(
      provider.occurrencesForDate(DateTime(2026, 9, 14)).map((o) => o.title),
      ['Rotta'],
    );
    expect(provider.occurrencesForDate(DateTime(2026, 9, 15)), isEmpty);
  });
}
