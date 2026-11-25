import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_service.dart';
import 'domain/todo.dart';
import 'domain/todo_order.dart';

/// Stato dei todo.
///
/// Ogni scrittura accoda la sua operazione in outbox nella stessa transazione, e
/// avanza il clock (`version` + `updated_at`) che il sync usa per i conflitti.
///
/// Un todo ricorrente si comporta diversamente da uno singolo: la sua riga
/// mostra **la prossima occorrenza**, e spuntarla segna **quella** occorrenza
/// (una riga per data in `occurrence_overrides`), non l'intera serie.
///
/// Gli scaduti da confermare stanno in `todo_overdue.dart` (un'estensione): questo
/// file è già il posto della coda, della ricorrenza, della cache e dello stato.
class TodoProvider extends ChangeNotifier {
  TodoProvider(this._db) {
    _loadTodos();
  }

  final DatabaseService _db;
  static const _uuid = Uuid();
  static const String _entity = 'todo';

  List<Todo> _todos = [];

  /// Le occorrenze fatte, per todo: una query sola, non una per giorno. La
  /// griglia del mese chiede 44 giorni × i ricorrenti, quindi senza questa
  /// cache erano centinaia di SELECT per disegnare un mese (misurato: 337 ms).
  /// Si azzera a ogni scrittura: si ricarica alla prima lettura successiva.
  ///
  /// Pubblica perche' la usano le estensioni che stanno in altri file
  /// (`todo_recurrence.dart`, `todo_overdue.dart`): fuori da li' non si usa.
  Map<String, Set<int>>? doneDays;

  /// Le finestre di giorni già calcolate, per non ripetere lo stesso lavoro a
  /// ogni ricostruzione. Tre in memoria (il mese corrente e i suoi vicini): le
  /// viste chiedono sempre le stesse, il resto è rumore. Si svuota a ogni
  /// scrittura — un todo nuovo e una conferma cambiano quello che c'è dentro.
  /// Le finestre gia' calcolate, per `todowindows.dart`: pubblica perche'
  /// l'estensione che le riempie sta in un altro file (e per il tetto di
  /// righe di questo). Non usarla da fuori: si svuota a ogni scrittura.
  final Map<(int, int), Map<DateTime, List<Todo>>> windows = {};

  /// Quante finestre si tengono in memoria.
  static const int maxWindows = 3;

  /// Le prossime occorrenze gia' calcolate, per todo.
  ///
  /// Perche' serve: la scheda chiede la prossima occorrenza di **ogni** todo a
  /// ogni ricostruzione, e calcolarla vuol dire espandere la regola su un anno.
  /// Misurato con l'agenda di prova: era il costo piu' grosso del build. Si
  /// azzera a ogni scrittura, come le finestre.
  ///
  /// Pubblica perche' la usa l'estensione `todo_recurrence.dart`.
  final Map<String, DateTime?> prossime = {};

  /// Il database, per le estensioni che scrivono o leggono fuori dal provider
  /// (`todo_recurrence.dart`): fuori da li' non si usa.
  DatabaseService get database => _db;

  List<Todo> get todos => _todos;

  int _generazione = 0;

  /// Quante volte i dati sono cambiati. Serve alla memoria delle viste del
  /// calendario: una vista che non si guardava non si e' ricostruita, quindi
  /// alla prossima occhiata deve sapere che quello che ha in mano e' vecchio.
  /// Sale su ogni scrittura, non sulle letture.
  int get generazione => _generazione;

  /// Rilegge tutto dal database. Serve a chi scrive **fuori** dal provider (i
  /// dati di prova, che girano in una transazione sola): senza, le viste
  /// restano con la copia in memoria di prima.
  void reload() => _loadTodos();

  /// L'ordine con cui la memoria consegna i todo: la regola sta in
  /// `domain/todo_order.dart`, perche' il file ha un tetto di righe ed e' una
  /// funzione pura (si prova senza database).
  void _ordina() => _todos.sort(confrontaTodo);

  /// Dopo una scrittura: rimette in ordine, butta le cache dipendenti dai dati e
  /// avvisa. **Senza rileggere il database**: con l'agenda di prova (150 todo) la
  /// rilettura completa dentro il fotogramma del gesto era un picco di 27 ms di
  /// build (misurato).
  void _dopoScrittura({String? id}) {
    _ordina();
    _invalidate(id: id);
    notifyListeners();
  }

  /// Butta le cache che dipendono dai dati: le conferme, le finestre del
  /// calendario e le prossime occorrenze ([id] nullo = tutte).
  void _invalidate({String? id}) {
    _generazione++;
    doneDays = null;
    windows.clear();
    if (id == null) {
      prossime.clear();
    } else {
      prossime.remove(id);
    }
  }

  void _loadTodos() {
    _todos = _db.getTodos().map(Todo.fromRow).toList();
    _invalidate();
    notifyListeners();
  }

  Future<void> addTodo({
    required String title,
    int priority = 0,
    DateTime? dueDate,
    int? startMinutes,
    int? endMinutes,
    List<String> categoryIds = const [],
    int? colorIndex,
    String recurrenceRule = '',
    String location = '',
    String note = '',
    List<int>? reminderLeads,
    bool? reminderSound,
  }) async {
    final todo = Todo(
      id: _uuid.v4(),
      title: title,
      priority: priority,
      dueDate: dueDate,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      categoryIds: categoryIds,
      colorIndex: colorIndex,
      recurrenceRule: recurrenceRule,
      location: location,
      note: note,
      reminderLeads: reminderLeads,
      reminderSound: reminderSound,
      updatedAt: DateTime.now(),
    );

    _write(
      () => _db.insertTodo(todo.toParams()),
      id: todo.id,
      version: todo.version,
      updatedAt: todo.updatedAt!,
      payload: todo.toParams(),
    );
    _todos = [..._todos, todo];
    _dopoScrittura(id: todo.id);
  }

  Future<void> updateTodo(Todo todo) async {
    final next = todo.copyWith(
      version: todo.version + 1,
      updatedAt: DateTime.now(),
    );

    _write(
      () => _db.updateTodo(next.toParams()),
      id: next.id,
      version: next.version,
      updatedAt: next.updatedAt!,
      payload: next.toParams(),
    );
    final indice = _todos.indexWhere((todo) => todo.id == next.id);
    _todos = indice < 0
        ? [..._todos, next]
        : (List<Todo>.of(_todos)..[indice] = next);
    _dopoScrittura(id: next.id);
  }

  Future<void> deleteTodo(String id) async {
    final clock = _db.entities.localClock(_entity, id);
    final now = DateTime.now();

    _write(
      () => _db.deleteTodo(id),
      id: id,
      version: (clock?.$1 ?? 0) + 1,
      updatedAt: now,
      payload: null,
    );
    _todos = [
      for (final todo in _todos)
        if (todo.id != id) todo
    ];
    _dopoScrittura(id: id);
  }

  /// Rimette un todo cancellato per sbaglio (l'undo dell'avviso).
  ///
  /// La versione sale di **due**: la cancellazione aveva già avanzato il clock
  /// di uno, e il ripristino deve vincere su quel record, altrimenti un altro
  /// dispositivo lo elimina di nuovo quando sincronizza.
  Future<void> restoreTodo(Todo todo) async {
    final next = todo.copyWith(
      version: todo.version + 2,
      updatedAt: DateTime.now(),
    );

    _write(
      () => _db.insertTodo(next.toParams()),
      id: next.id,
      version: next.version,
      updatedAt: next.updatedAt!,
      payload: next.toParams(),
    );
    _todos = [..._todos, next];
    _dopoScrittura(id: next.id);
  }

  /// Dopo una scrittura fatta **da un'estensione** (la ricorrenza, in
  /// `todo_recurrence.dart`): le finestre del calendario non valgono piu', e la
  /// generazione deve salire perche' le viste in memoria lo sappiano.
  void dopoScritturaEsterna() {
    windows.clear();
    _generazione++;
    notifyListeners();
  }

  /// Scrive **molti** todo in **una** transazione: o passano tutti, o nessuno.
  ///
  /// Serve alla selezione multipla: spuntare o spostare venti todo deve essere
  /// una modifica sola, non venti. `nuovo` a `null` cancella; con [rimetti] le
  /// righe cancellate **tornano** al loro posto (l'annulla di una cancellazione
  /// multipla).
  ///
  /// La versione sale di uno per ciascuno, e di **due** con [rimetti]: la
  /// cancellazione aveva gia' avanzato il clock (come in `restoreTodo`).
  void scriviMolti(List<(Todo, Todo?)> voci, {bool rimetti = false}) {
    final adesso = DateTime.now();
    _db.runInTransaction(() {
      for (final (vecchio, nuovo) in voci) {
        final versione = vecchio.version + (rimetti ? 2 : 1);
        final pronto = nuovo?.copyWith(version: versione, updatedAt: adesso);
        if (pronto == null) {
          _db.deleteTodo(vecchio.id);
        } else if (rimetti) {
          _db.insertTodo(pronto.toParams());
        } else {
          _db.updateTodo(pronto.toParams());
        }
        _db.outbox.enqueue(
          operationId: _uuid.v4(),
          entity: _entity,
          entityId: vecchio.id,
          operation: pronto == null ? 'delete' : 'upsert',
          version: versione,
          updatedAt: adesso.millisecondsSinceEpoch,
          payload: pronto?.toParams() ?? const {},
        );
      }
    });

    // In memoria, la stessa cosa: sostituisci, togli, o rimetti in coda.
    final perId = {for (final (vecchio, nuovo) in voci) vecchio.id: nuovo};
    _todos = [
      for (final todo in _todos)
        if (!perId.containsKey(todo.id))
          todo
        else if (perId[todo.id] != null)
          perId[todo.id]!,
      for (final (vecchio, nuovo) in voci)
        if (nuovo != null && !_todos.any((todo) => todo.id == vecchio.id))
          nuovo,
    ];
    _dopoScrittura();
  }

  void _write(
    void Function() apply, {
    required String id,
    required int version,
    required DateTime updatedAt,
    required Map<String, Object?>? payload,
  }) {
    _db.runInTransaction(() {
      apply();
      _db.outbox.enqueue(
        operationId: _uuid.v4(),
        entity: _entity,
        entityId: id,
        operation: payload == null ? 'delete' : 'upsert',
        version: version,
        updatedAt: updatedAt.millisecondsSinceEpoch,
        payload: payload ?? const {},
      );
    });
  }
}
