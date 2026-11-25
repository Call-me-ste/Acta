import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/calendar_import/domain/calendar_selection.dart';
import 'package:planner/features/calendar_import/domain/device_calendar_gateway.dart';

void main() {
  const personale = DeviceCalendarInfo(
    id: 'p',
    name: 'Personale',
    accountName: 'me@gmail.com',
    isPrimary: true,
  );
  const secondario = DeviceCalendarInfo(
    id: 's',
    name: 'Lavoro',
    accountName: 'me@gmail.com',
  );
  const festivita = DeviceCalendarInfo(
    id: 'f',
    name: 'Festività in Italia',
    accountName: 'me@gmail.com',
    readOnly: true,
  );

  test('riconosce festività, compleanni e calendari tecnici', () {
    expect(isSystemCalendar(festivita), isTrue);
    expect(
      isSystemCalendar(
        const DeviceCalendarInfo(id: 'b', name: 'Compleanni'),
      ),
      isTrue,
    );
    expect(
      isSystemCalendar(
        const DeviceCalendarInfo(
          id: 'o',
          name: 'oplus_countdown_default_calendar',
        ),
      ),
      isTrue,
    );
    expect(isSystemCalendar(personale), isFalse);
  });

  test('il calendario locale ha un nome e una spiegazione', () {
    const locale = DeviceCalendarInfo(
      id: 'l',
      name: 'local account',
      accountName: 'local account',
    );
    expect(calendarName(locale), 'Calendario locale');
    expect(
      calendarSubtitle(locale),
      'Eventi salvati solo su questo telefono',
    );
    // Alcuni produttori lo chiamano «Phone» e lo segnano con accountType local.
    const samsung = DeviceCalendarInfo(
      id: 's',
      name: 'Phone',
      accountType: 'local',
    );
    expect(calendarName(samsung), 'Calendario locale');
  });

  test('la selezione iniziale preferisce i principali scrivibili', () {
    final scelti = defaultCalendars([
      personale,
      secondario,
      festivita,
      const DeviceCalendarInfo(
        id: 'letto',
        name: 'Condiviso',
        readOnly: true,
      ),
    ]);

    expect(scelti.map((calendar) => calendar.id), ['p']);
  });

  test('senza principali prende un calendario per account', () {
    const principaleGmail = DeviceCalendarInfo(
      id: 'g',
      name: 'me@gmail.com',
      accountName: 'me@gmail.com',
    );
    final scelti = defaultCalendars([
      secondario,
      principaleGmail,
      festivita,
    ]);

    expect(scelti.map((calendar) => calendar.id), ['g']);
  });

  test('i principali vengono prima nell’elenco', () {
    final ordinati = [secondario, personale]..sort(compareCalendars);
    expect(ordinati.first.id, 'p');
  });

  test('due calendari locali identici restano un gruppo solo', () {
    const primo = DeviceCalendarInfo(
      id: 'l1',
      name: 'Calendario locale',
      accountType: 'local',
    );
    const secondo = DeviceCalendarInfo(
      id: 'l2',
      name: 'Calendario locale',
      accountType: 'local',
    );
    expect(calendarGroupKey(primo), calendarGroupKey(secondo));
    expect(
      defaultCalendars([primo, secondo]).map((calendar) => calendar.id),
      ['l1', 'l2'],
    );
  });
}
