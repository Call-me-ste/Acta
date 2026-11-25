/// Il ponte verso il **calendario del telefono**, senza dipendere dal plugin
/// nella logica: la pagina e i test parlano con questa interfaccia.
///
/// L'import è una tantum: si leggono gli eventi una volta e diventano eventi
/// normali del Planner. Non c'è nessun collegamento permanente al calendario
/// esterno, quindi niente sincronizzazione, conflitti o permessi che restano
/// aperti.
library;

enum CalendarAccess {
  granted,
  denied,
  restricted,
  unavailable,
}

class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    this.accountName,
    this.accountType,
    this.colorHex,
    this.readOnly = false,
    this.isPrimary = false,
    this.hidden = false,
  });

  final String id;
  final String name;
  final String? accountName;

  /// Tipo account Android (`local`, `com.google`, …): serve a riconoscere il
  /// calendario locale anche quando il produttore lo chiama «Phone».
  final String? accountType;
  final String? colorHex;
  final bool readOnly;

  /// Il calendario su cui il sistema scrive di default per quell'account.
  final bool isPrimary;

  /// Nascosto nell'app calendario del telefono.
  final bool hidden;
}

class DeviceCalendarEvent {
  const DeviceCalendarEvent({
    required this.eventId,
    required this.instanceId,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    this.description,
    this.location,
    this.allDay = false,
    this.colorHex,
    this.reminders = const [],
    this.url,
  });

  final String eventId;
  final String instanceId;
  final String calendarId;
  final String title;
  final String? description;
  final String? location;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? colorHex;

  /// Minuti di anticipo, già normalizzati dal gateway.
  final List<int> reminders;
  final String? url;
}

/// L'intervallo di import scelto dall'utente. Sta nel dominio perché è una
/// regola di prodotto, non un dettaglio della pagina.
enum ImportPeriod {
  next12,
  last12,
  fiveYears;

  String get label => switch (this) {
        next12 => 'Prossimi 12 mesi',
        last12 => 'Ultimi 12 mesi',
        fiveYears => '5 anni',
      };

  (DateTime, DateTime) range(DateTime now) {
    final oggi = DateTime(now.year, now.month, now.day);
    return switch (this) {
      next12 => (oggi, oggi.add(const Duration(days: 365))),
      last12 => (oggi.subtract(const Duration(days: 365)), oggi),
      fiveYears => (
          oggi.subtract(const Duration(days: 365 * 2)),
          oggi.add(const Duration(days: 365 * 3)),
        ),
    };
  }
}

abstract class DeviceCalendarGateway {
  /// Chiede il permesso di sistema. Su desktop restituisce [unavailable].
  Future<CalendarAccess> requestAccess();

  Future<List<DeviceCalendarInfo>> calendars();

  Future<List<DeviceCalendarEvent>> events({
    required Set<String> calendarIds,
    required DateTime from,
    required DateTime to,
  });

  Future<void> openSettings();
}

class DeviceCalendarException implements Exception {
  const DeviceCalendarException(this.message);

  final String message;

  @override
  String toString() => message;
}
