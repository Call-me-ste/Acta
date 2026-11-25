import 'package:flutter/widgets.dart';

import '../../core/perf/frame_log.dart';

/// La memoria delle tre viste del calendario.
///
/// Senza questa memoria, ogni ricostruzione della pagina (e ogni cambio vista lo
/// e', perche' la scelta sta nelle preferenze) ricostruiva **tutte e tre** le
/// viste: la griglia del mese, le 168 celle della settimana e la timeline del
/// giorno rientravano nel fotogramma dell'animazione — misurato in 30-55 ms di
/// build sull'emulatore. Restituendo la **stessa istanza** quando la chiave non e'
/// cambiata, Flutter non ricostruisce niente: cambia solo la posizione.
///
/// E solo la vista che si sta **guardando** si ricostruisce quando cambia il
/// giorno: le altre restano com'erano e si allineano quando diventano attive. Il
/// perche' e' nei numeri — a ogni cambio giorno si ricostruivano tutte e tre, con
/// un fotogramma da 13 ms di lavoro Dart.
///
/// Una classe sola con tre slot, invece di tre metodi identici: erano la stessa
/// regola scritta tre volte, e la regola e' una.
class CalendarViewCache {
  /// Gli slot, nell'ordine della pillola.
  static const int mese = 0;
  static const int settimana = 1;
  static const int giorno = 2;

  static const int _slot = 3;

  /// I nomi, per la sonda: con `--dart-define=frameLog=true` dice quali viste si
  /// ricostruiscono, da leggere insieme ai tempi dei fotogrammi.
  static const List<String> _nomi = ['mese', 'settimana', 'giorno'];

  final List<Widget?> _viste = List<Widget?>.filled(_slot, null);
  final List<Object?> _chiavi = List<Object?>.filled(_slot, null);

  /// La vista dello slot [indice], ricordata finche' [chiave] non cambia.
  ///
  /// Se [attiva] e' falsa la vista **non** si ricostruisce: e' quella che non si
  /// vede, e rifarla per un giorno che non si guarda era il costo da togliere.
  Widget vista(
    int indice,
    bool attiva,
    Object chiave,
    Widget Function() costruisci,
  ) {
    final viva = _viste[indice];
    if (viva != null) {
      if (!attiva) return viva;
      if (_chiavi[indice] == chiave) return viva;
    }

    if (frameLogEnabled) debugPrint('MEMO ${_nomi[indice]}: ricostruita');
    _chiavi[indice] = chiave;
    return _viste[indice] = costruisci();
  }
}
