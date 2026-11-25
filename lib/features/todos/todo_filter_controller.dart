import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../core/database/settings_store.dart';
import 'todo_filter.dart';

/// Il filtro della scheda Todo, ricordato fra un avvio e l'altro.
///
/// Sta nelle preferenze del **device** (come tema e palette): e' una lente che
/// si usa per guardare, non un dato da sincronizzare — sul telefono posso voler
/// vedere "Oggi" e sul PC "Tutte".
class TodoFilterController extends ChangeNotifier {
  TodoFilterController(this._store);

  final SettingsStore _store;

  static const String _rangeKey = 'todoFilterRange';
  static const String _categoriesKey = 'todoFilterCategories';
  static const String _prioritiesKey = 'todoFilterPriorities';

  TodoFilter _filter = const TodoFilter();

  TodoFilter get filter => _filter;

  /// Vero quando non c'e' nessun vincolo: e' anche il filtro di partenza.
  bool get isDefault => _filter.isEmpty;

  void load() {
    _filter = TodoFilter(
      range: _rangeOf(_store.get(_rangeKey)),
      categoryIds: _idsOf(_store.get(_categoriesKey)),
      priorities: _intsOf(_store.get(_prioritiesKey)),
    );
    notifyListeners();
  }

  void setRange(TodoRange range) {
    if (range == _filter.range) return;
    _apply(_filter.copyWith(range: range));
  }

  void toggleCategory(String categoryId) {
    final next = Set<String>.of(_filter.categoryIds);
    if (!next.remove(categoryId)) next.add(categoryId);
    _apply(_filter.copyWith(categoryIds: next));
  }

  void togglePriority(int priority) {
    final next = Set<int>.of(_filter.priorities);
    if (!next.remove(priority)) next.add(priority);
    _apply(_filter.copyWith(priorities: next));
  }

  /// Torna a "Tutte, senza vincoli" e toglie le chiavi: cosi' il default e' di
  /// nuovo "non impostato" e non una copia salvata dei valori di oggi.
  void reset() {
    _filter = const TodoFilter();
    _store.remove(_rangeKey);
    _store.remove(_categoriesKey);
    _store.remove(_prioritiesKey);
    notifyListeners();
  }

  void _apply(TodoFilter filter) {
    _filter = filter;

    // Un filtro tornato vuoto toglie la chiave invece di scrivere "niente".
    if (filter.range == TodoRange.tutte) {
      _store.remove(_rangeKey);
    } else {
      _store.set(_rangeKey, filter.range.name);
    }
    if (filter.categoryIds.isEmpty) {
      _store.remove(_categoriesKey);
    } else {
      _store.set(_categoriesKey, filter.categoryIds.join(','));
    }
    if (filter.priorities.isEmpty) {
      _store.remove(_prioritiesKey);
    } else {
      _store.set(_prioritiesKey, (filter.priorities.toList()..sort()).join(','));
    }

    notifyListeners();
  }

  /// Un valore sconosciuto ricade su "Tutte": una preferenza scritta da una
  /// versione piu' recente non deve lasciare la scheda vuota.
  static TodoRange _rangeOf(String? raw) {
    for (final range in TodoRange.values) {
      if (range.name == raw) return range;
    }
    return TodoRange.tutte;
  }

  static Set<String> _idsOf(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    return raw.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
  }

  static Set<int> _intsOf(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    return raw
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toSet();
  }
}
