import 'package:flutter_test/flutter_test.dart';
import 'package:planner/ui/shared/due_date_label.dart';

/// Come si legge una scadenza, e il conto dei giorni.
///
/// Il conto e' in giorni di **calendario**: con la differenza fra istanti, la
/// notte del cambio d'ora un todo di domani risultava di zero giorni, cioe'
/// "Oggi" su una cosa che era domani.
void main() {
  final oggi = DateTime(2026, 9, 17, 23, 30);

  test('i giorni sono di calendario, non di orologio', () {
    // Mezzanotte e mezza di domani: manca un giorno, non zero.
    expect(daysUntilDue(DateTime(2026, 9, 18, 0, 30), from: oggi), 1);
    // Le 23:30 di oggi sono "oggi", non "-1".
    expect(daysUntilDue(DateTime(2026, 9, 17, 0, 5), from: oggi), 0);
    expect(daysUntilDue(DateTime(2026, 9, 16, 23, 0), from: oggi), -1);
  });

  test('le parole sono quelle che si leggono', () {
    expect(dueLabel(DateTime(2026, 9, 17), from: oggi), 'Oggi');
    expect(dueLabel(DateTime(2026, 9, 18), from: oggi), 'Domani');
    expect(dueLabel(DateTime(2026, 9, 16), from: oggi), 'Scaduta da 1 giorno');
    expect(dueLabel(DateTime(2026, 9, 14), from: oggi), 'Scaduta da 3 giorni');
    expect(dueLabel(DateTime(2026, 9, 20), from: oggi), 'Tra 3 giorni');
    expect(dueLabel(DateTime(2026, 9, 24), from: oggi), 'Tra 7 giorni');
    // Lontana: la data, che e' piu' utile di "tra 43 giorni".
    expect(dueLabel(DateTime(2026, 10, 30), from: oggi), '30/10/2026');
  });

  test('oggi non e\' scaduto: la giornata non e\' finita', () {
    expect(isOverdue(DateTime(2026, 9, 17), from: oggi), isFalse);
    expect(isOverdue(DateTime(2026, 9, 16), from: oggi), isTrue);
  });
}
