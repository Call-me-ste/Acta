import 'package:sqlite3/sqlite3.dart';

import '../../../core/categories/category_ids.dart';
import '../../../core/reminders/reminder_leads.dart';

/// Un evento del calendario.
///
/// La conversione da/verso SQLite vive qui, in un solo posto, e `toParams()`
/// produce **sempre** `int` 0/1 per i booleani: un `bool` passato a SQLite non è
/// un tipo valido. Prima del modello tipato la lettura restituiva `bool`
/// (`all_day`) mentre la scrittura pretendeva `int`, ed è così che è nato un
/// crash a runtime (`true as int`) che il compilatore non poteva vedere.
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.description = '',
    this.allDay = false,
    this.colorIndex = 0,
    this.colorHex,
    this.recurrenceRule = '',
    this.reminderLeads,
    this.reminderSound,
    this.location = '',
    this.note = '',
    this.categoryIds = const [],
    this.version = 1,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final bool allDay;

  /// Indice nella palette attiva. Vale **solo** se [colorHex] è nullo.
  final int colorIndex;

  /// Colore scelto a mano (`#ff69b4`): vince sulla palette. Nullo = usa la
  /// palette, che è il caso normale.
  final String? colorHex;

  final String recurrenceRule;

  /// Con quanti minuti di anticipo avvisare: `null` = default delle
  /// impostazioni, elenco vuoto = nessun promemoria per questo evento, uno o
  /// più anticipi altrimenti (`[15, 60]` = un quarto d'ora e un'ora prima).
  final List<int>? reminderLeads;

  /// Il suono del promemoria: `null` = eredita l'impostazione, altrimenti
  /// acceso/spento per questo evento soltanto.
  final bool? reminderSound;

  /// Dove succede (`Via Roma 1`). Serve all'utente, e alimenta i suggerimenti
  /// dei posti già usati.
  final String location;

  /// Nota libera dell'elemento. È distinta da [description], che è il testo
  /// lungo dell'evento (importato) e non si modifica dal form.
  final String note;

  /// Le categorie scelte (da 1 a 3, vedi `core/categories/category_ids.dart`).
  /// L'elenco sta sull'elemento e non sulla categoria: cosi' cancellare una
  /// categoria non porta via il contenuto, e il sync copia una riga sola.
  final List<String> categoryIds;

  final int version;
  final DateTime? updatedAt;

  factory Event.fromRow(Row row) {
    return Event(
      id: row['id'] as String,
      title: row['title'] as String,
      description: (row['description'] as String?) ?? '',
      start: DateTime.fromMillisecondsSinceEpoch(row['start_time'] as int),
      end: DateTime.fromMillisecondsSinceEpoch(row['end_time'] as int),
      allDay: (row['all_day'] as int? ?? 0) == 1,
      colorIndex: row['color_index'] as int? ?? 0,
      colorHex: row['color_hex'] as String?,
      recurrenceRule: (row['recurrence_rule'] as String?) ?? '',
      reminderLeads: decodeReminderLeads(row['reminder_leads']),
      reminderSound: _boolOrNull(row['reminder_sound']),
      location: (row['location'] as String?) ?? '',
      note: (row['note'] as String?) ?? '',
      categoryIds: decodeCategoryIds(row['category_ids']),
      version: row['version'] as int? ?? 1,
      updatedAt: _dateTimeOrNull(row['updated_at']),
    );
  }

  Map<String, Object?> toParams() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_time': start.millisecondsSinceEpoch,
      'end_time': end.millisecondsSinceEpoch,
      'all_day': allDay ? 1 : 0,
      'color_index': colorIndex,
      'color_hex': colorHex,
      'recurrence_rule': recurrenceRule,
      'reminder_leads': encodeReminderLeads(reminderLeads),
      'reminder_sound': reminderSound == null ? null : (reminderSound! ? 1 : 0),
      'location': location,
      'note': note,
      'category_ids': encodeCategoryIds(categoryIds),
      'version': version,
      // Il clock viaggia col record: serve al sync per decidere chi vince, e
      // per un insert resta fuori (lo mette il database col suo default).
      if (updatedAt != null) 'updated_at': updatedAt!.millisecondsSinceEpoch,
    };
  }

  Event copyWith({
    String? title,
    String? description,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    int? colorIndex,
    Object? colorHex = _unset,
    String? recurrenceRule,
    Object? reminderLeads = _unset,
    Object? reminderSound = _unset,
    String? location,
    String? note,
    List<String>? categoryIds,
    int? version,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      start: start ?? this.start,
      end: end ?? this.end,
      allDay: allDay ?? this.allDay,
      colorIndex: colorIndex ?? this.colorIndex,
      // Sentinella come in `Todo.dueDate`: senza, non si potrebbe *togliere* il
      // colore libero (null direbbe insieme "lascia" e "azzera").
      colorHex:
          identical(colorHex, _unset) ? this.colorHex : colorHex as String?,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      reminderLeads: identical(reminderLeads, _unset)
          ? this.reminderLeads
          : reminderLeads as List<int>?,
      reminderSound: identical(reminderSound, _unset)
          ? this.reminderSound
          : reminderSound as bool?,
      location: location ?? this.location,
      note: note ?? this.note,
      categoryIds: categoryIds ?? this.categoryIds,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Object _unset = Object();

  static DateTime? _dateTimeOrNull(Object? millis) {
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis as int);
  }

  /// Il suono è a tre stati, quindi `null` (eredita) va distinto da 0 (spento).
  static bool? _boolOrNull(Object? value) =>
      value == null ? null : (value as int) == 1;
}
