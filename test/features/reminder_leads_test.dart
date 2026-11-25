import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/reminders/reminder_leads.dart';

/// Gli anticipi del promemoria vivono in una colonna di testo (`reminder_leads`)
/// e possono arrivare **da un altro dispositivo**: vanno letti in modo
/// tollerante (un valore corrotto si scarta, non fa esplodere il sync) e
/// riscritti in modo stabile, così due device scrivono la stessa stringa per lo
/// stesso elenco.
void main() {
  group('codifica', () {
    test('null vuol dire "usa il default", lista vuota "nessuno"', () {
      expect(encodeReminderLeads(null), isNull);
      expect(encodeReminderLeads(const []), '');
    });

    test('ordina e toglie i doppioni', () {
      expect(encodeReminderLeads(const [60, 15, 15, 5]), '5,15,60');
    });
  });

  group('decodifica', () {
    test('legge un elenco e lo restituisce ordinato', () {
      expect(decodeReminderLeads('60,15'), [15, 60]);
    });

    test('distingue "nessuno" da "default"', () {
      expect(decodeReminderLeads(''), isEmpty);
      expect(decodeReminderLeads(null), isNull);
      expect(decodeReminderLeads('   '), isEmpty);
    });

    test('un valore corrotto si scarta da solo, non l\'elenco', () {
      expect(decodeReminderLeads('15,pippo,-5,,60'), [15, 60]);
    });

    test('una settimana è il tetto: oltre, il valore non esiste', () {
      expect(decodeReminderLeads('10080'), [10080]);
      expect(decodeReminderLeads('10081'), isEmpty);
    });

    test('round-trip: quello che scrivo è quello che rileggo', () {
      const leads = [1440, 15, 30];
      expect(decodeReminderLeads(encodeReminderLeads(leads)), [15, 30, 1440]);
    });
  });
}
