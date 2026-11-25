import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../core/database/settings_store.dart';
import 'filtro_condiviso.dart';

/// Il filtro condiviso, ricordato fra un avvio e l'altro.
///
/// Sta nelle preferenze del **device**, come il filtro dei todo: e' una lente
/// che si usa per guardare, non un dato da sincronizzare — sul telefono posso
/// voler vedere solo una categoria e sul PC tutto.
class FiltroCondivisoController extends ChangeNotifier {
  FiltroCondivisoController(this._store);

  final SettingsStore _store;

  static const String _categorieKey = 'filtroCondivisoCategorie';
  static const String _cosaKey = 'filtroCondivisoCosa';
  static const String _orizzonteKey = 'filtroCondivisoOrizzonte';

  FiltroCondiviso _filtro = const FiltroCondiviso();

  FiltroCondiviso get filtro => _filtro;

  /// Vero quando non c'e' nessun vincolo: e' il filtro di partenza.
  bool get isDefault => _filtro.isEmpty;

  void load() {
    _filtro = FiltroCondiviso(
      categorieScelte: _idsOf(_store.get(_categorieKey)),
      cosa: _enumOf(
        CosaMostrare.values,
        _store.get(_cosaKey),
        CosaMostrare.entrambi,
      ),
      orizzonte: _enumOf(
        Orizzonte.values,
        _store.get(_orizzonteKey),
        Orizzonte.giorni30,
      ),
    );
    notifyListeners();
  }

  void toggleCategoria(String categoryId) {
    final next = Set<String>.of(_filtro.categorieScelte);
    if (!next.remove(categoryId)) next.add(categoryId);
    _apply(_filtro.copyWith(categorieScelte: next));
  }

  void setCosa(CosaMostrare cosa) {
    if (cosa == _filtro.cosa) return;
    _apply(_filtro.copyWith(cosa: cosa));
  }

  void setOrizzonte(Orizzonte orizzonte) {
    if (orizzonte == _filtro.orizzonte) return;
    _apply(_filtro.copyWith(orizzonte: orizzonte));
  }

  /// Torna al filtro di partenza e toglie le chiavi: cosi' il default e' di
  /// nuovo "non impostato" e non una copia salvata dei valori di oggi.
  void reset() => _apply(const FiltroCondiviso());

  void clearCalendarFilters() =>
      _apply(FiltroCondiviso(orizzonte: _filtro.orizzonte));

  void _apply(FiltroCondiviso filtro) {
    _filtro = filtro;
    // La UI si aggiorna **subito**, la scrittura aspetta la fine del fotogramma:
    // cambiare filtro ricostruisce la vista, e una scrittura SQLite dentro quel
    // fotogramma si vede (e' la misura che ha portato a scrivere cosi' anche le
    // preferenze del tema, in `AppSettingsController`). Una microattivita', non
    // un callback di fine fotogramma: i test di questa classe sono prove pure,
    // senza schermo.
    notifyListeners();
    scheduleMicrotask(() {
      // Un filtro tornato al default toglie la chiave invece di scrivere
      // "niente": cosi' "non impostato" resta distinguibile da "impostato al
      // valore di oggi".
      _scrivi(
        _categorieKey,
        filtro.categorieScelte.isEmpty
            ? null
            : (filtro.categorieScelte.toList()..sort()).join(','),
      );
      _scrivi(
        _cosaKey,
        filtro.cosa == CosaMostrare.entrambi ? null : filtro.cosa.name,
      );
      _scrivi(
        _orizzonteKey,
        filtro.orizzonte == Orizzonte.giorni30 ? null : filtro.orizzonte.name,
      );
    });
  }

  void _scrivi(String key, String? value) {
    if (value == null) {
      _store.remove(key);
    } else {
      _store.set(key, value);
    }
  }

  /// Un valore sconosciuto ricade sul default: una preferenza scritta da una
  /// versione piu' recente non deve svuotare l'agenda.
  static Set<String> _idsOf(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    return raw
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static T _enumOf<T extends Enum>(List<T> values, String? raw, T fallback) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }
}
