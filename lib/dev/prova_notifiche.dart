import '../core/database/database_service.dart';

/// Gli eventi dei **dati di prova** che servono a vedere arrivare una notifica
/// sul telefono: uno fra due minuti, uno fra quattro, con un anticipo di **un
/// minuto**.
///
/// Perché un file suo: `demo_data.dart` è già al tetto delle righe, e questa è
/// una cosa a sé — non serve a riempire l'agenda, serve alla **prova** delle
/// notifiche. Creare l'evento dall'app vorrebbe dire litigare col selettore
/// dell'ora (una ghiera, e su questa OPPO i tocchi arrivano in ritardo): così si
/// caricano i dati di prova e si aspetta.
///
/// L'anticipo di un minuto è quello che fa la differenza: il default delle
/// impostazioni è 15, e un avviso **già passato** non si pianifica — con 15
/// minuti di anticipo su un evento fra due minuti, non arriverebbe niente.
class ProvaNotifiche {
  const ProvaNotifiche._();

  /// Quanti eventi scrive: lo leggono i test dei dati di prova, così aggiungerne
  /// un terzo non fa fallire il conteggio per il motivo sbagliato.
  static const int quanti = 2;

  /// Le due prove: la seconda si usa per le **ore silenziose** (deve arrivare
  /// muta, sul canale silenzioso).
  static const List<(String, int)> _eventi = [
    ('Prova notifica', 2),
    ('Prova notifica silenziosa', 4),
  ];

  /// Scrive gli eventi e torna quanti ne ha messi.
  static int carica(DatabaseService db, {required String idPrefix}) {
    assert(_eventi.length == quanti);

    final adesso = DateTime.now();
    for (var i = 0; i < _eventi.length; i++) {
      final (titolo, minuti) = _eventi[i];
      final quando = adesso.add(Duration(minutes: minuti));
      db.insertEvent({
        'id': '${idPrefix}prova-$i',
        'title': titolo,
        'description': 'Evento creato dai dati di prova per vedere arrivare '
            'una notifica',
        'start_time': quando.millisecondsSinceEpoch,
        'end_time':
            quando.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
        'color_index': i,
        'reminder_leads': '1',
        'version': 1,
        'updated_at': adesso.millisecondsSinceEpoch,
      });
    }
    return _eventi.length;
  }
}
