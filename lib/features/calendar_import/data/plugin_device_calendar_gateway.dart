import 'dart:io';

import 'package:device_calendar_plus/device_calendar_plus.dart' as device;

import '../domain/device_calendar_gateway.dart';

/// L'unico punto che parla con il plugin di sistema. Tutto il resto usa
/// [DeviceCalendarGateway], così l'import si prova senza telefono.
class PluginDeviceCalendarGateway implements DeviceCalendarGateway {
  PluginDeviceCalendarGateway({device.DeviceCalendar? calendar})
      : _calendar = calendar ?? device.DeviceCalendar.instance;

  final device.DeviceCalendar _calendar;

  bool get _supportato => Platform.isAndroid || Platform.isIOS;

  @override
  Future<CalendarAccess> requestAccess() async {
    if (!_supportato) return CalendarAccess.unavailable;
    try {
      final stato = await _calendar.requestPermissions();
      return switch (stato) {
        device.CalendarPermissionStatus.granted => CalendarAccess.granted,
        device.CalendarPermissionStatus.restricted => CalendarAccess.restricted,
        device.CalendarPermissionStatus.notDetermined => CalendarAccess.denied,
        device.CalendarPermissionStatus.denied => CalendarAccess.denied,
        device.CalendarPermissionStatus.writeOnly => CalendarAccess.denied,
      };
    } on device.DeviceCalendarException catch (errore) {
      if (errore.errorCode == device.DeviceCalendarError.calendarUnavailable) {
        return CalendarAccess.unavailable;
      }
      throw DeviceCalendarException(_messaggio(errore));
    }
  }

  @override
  Future<List<DeviceCalendarInfo>> calendars() async {
    if (!_supportato) return const [];
    try {
      final result = await _calendar.listCalendars();
      final visti = <String>{};
      return [
        for (final calendar in result)
          if (visti.add(calendar.id))
            DeviceCalendarInfo(
              id: calendar.id,
              name: calendar.name,
              accountName: calendar.accountName,
              accountType: calendar.accountType,
              colorHex: calendar.colorHex,
              readOnly: calendar.readOnly,
              isPrimary: calendar.isPrimary,
              hidden: calendar.hidden,
            ),
      ];
    } on device.DeviceCalendarException catch (errore) {
      throw DeviceCalendarException(_messaggio(errore));
    }
  }

  @override
  Future<List<DeviceCalendarEvent>> events({
    required Set<String> calendarIds,
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_supportato || calendarIds.isEmpty) return const [];
    try {
      final result = await _calendar.listEvents(
        from,
        to,
        calendarIds: calendarIds.toList(),
      );
      return [
        for (final evento in result)
          if (evento.status != device.EventStatus.canceled)
            DeviceCalendarEvent(
              eventId: evento.eventId,
              instanceId: evento.instanceId,
              calendarId: evento.calendarId,
              title: evento.title,
              description: evento.description,
              location: evento.location,
              start: evento.startDate,
              end: evento.endDate,
              allDay: evento.isAllDay,
              colorHex: evento.colorHex,
              reminders: [
                for (final anticipo in evento.reminders ?? const <Duration>[])
                  if (anticipo.inMinutes > 0) anticipo.inMinutes,
              ],
              url: evento.url,
            ),
      ];
    } on device.DeviceCalendarException catch (errore) {
      throw DeviceCalendarException(_messaggio(errore));
    }
  }

  @override
  Future<void> openSettings() async {
    if (!_supportato) return;
    await _calendar.openAppSettings();
  }

  static String _messaggio(device.DeviceCalendarException errore) {
    return switch (errore.errorCode) {
      device.DeviceCalendarError.permissionsNotDeclared =>
        'Il Planner non ha il permesso per il calendario. Controlla le '
            'impostazioni di sistema.',
      device.DeviceCalendarError.permissionDenied =>
        'Accesso al calendario negato.',
      device.DeviceCalendarError.calendarUnavailable =>
        'Il calendario del telefono non è disponibile.',
      _ => 'Non è stato possibile leggere il calendario del telefono.',
    };
  }
}
