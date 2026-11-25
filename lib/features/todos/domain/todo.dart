import 'package:sqlite3/sqlite3.dart';

import '../../../core/categories/category_ids.dart';
import '../../../core/reminders/reminder_leads.dart';

/// Un todo.
///
/// Come `Event`, la conversione da/verso SQLite vive qui e `toParams()` produce
/// sempre `int` 0/1 per i booleani.
class Todo {
  const Todo({
    required this.id,
    required this.title,
    this.completed = false,
    this.priority = 0,
    this.dueDate,
    this.startMinutes,
    this.endMinutes,
    this.hiddenInCalendar = false,
    this.categoryIds = const [],
    this.colorIndex,
    this.recurrenceRule = '',
    this.reminderLeads,
    this.reminderSound,
    this.location = '',
    this.note = '',
    this.version = 1,
    this.updatedAt,
  });

  final String id;
  final String title;
  final bool completed;

  /// 0 = Bassa, 1 = Media, 2 = Alta, 3 = Urgente. Il DB ordina `priority DESC`,
  /// quindi i più urgenti vengono per primi.
  final int priority;

  final DateTime? dueDate;

  /// Gli **orari** del todo, in minuti dalla mezzanotte (0-1439). Nulli = nessun
  /// orario: la data da sola basta, ed e' lo stato di quasi tutti i todo.
  ///
  /// Si possono avere anche da soli (solo inizio, solo fine): per gli eventi le
  /// due estremita' si completano a vicenda, per un todo «dalle 8» e «entro le
  /// 18» sono due cose diverse e legittime.
  final int? startMinutes;
  final int? endMinutes;

  /// Vero quando il todo e' stato tolto **dal calendario** (scorrimento a
  /// destra su una riga delle griglie). Resta nella scheda Todo e in Agenda:
  /// il segno dice dove **non** si vuole vederlo, non che e' cancellato.
  final bool hiddenInCalendar;

  /// Il primo orario che c'e': serve all'ordinamento e a chi mostra «dalle 8».
  int? get firstTime => startMinutes ?? endMinutes;

  /// Quanto dura, in **minuti**: quello che dice lui, o un'ora quando l'orario di
  /// fine non c'e' («dalle 8» e «entro le 18» sono un'ora di spazio). E' la
  /// regola con cui le griglie di mese/settimana/giorno danno a un todo la
  /// casella di un evento della stessa durata: sta qui perche' e' **una**.
  int get durationMinutes {
    final fine = endMinutes;
    final inizio = startMinutes ?? ((fine ?? 0) - 60);
    return (fine ?? inizio + 60) - inizio;
  }

  /// Le categorie scelte (da 1 a 3). Prima c'era un `category` di testo libero
  /// che l'interfaccia non ha mai mostrato: al primo avvio viene convertito in
  /// una categoria vera (vedi `CategoryController.migrateLegacyCategoryColumn`).
  final List<String> categoryIds;

  /// Colore scelto a mano (indice nella palette attiva). Nullo = nessun colore:
  /// il todo resta neutro finché l'utente non lo colora di proposito. La
  /// priorità ha i suoi colori semantici e non viene mappata sulla palette.
  final int? colorIndex;

  /// La regola di ricorrenza serializzata (`FREQ=WEEKLY;BYDAY=MO,WE`), vuota se
  /// il todo non ricorre. `dueDate` fa da data di partenza della serie.
  final String recurrenceRule;

  /// Come su `Event`: `null` = default delle impostazioni, elenco vuoto =
  /// nessun promemoria, altrimenti i minuti di anticipo.
  final List<int>? reminderLeads;

  /// `null` = eredita l'impostazione, altrimenti acceso/spento per questo todo.
  final bool? reminderSound;

  /// Dove va fatto (`Esselunga`), con gli stessi suggerimenti degli eventi.
  final String location;

  /// Nota libera dell'elemento.
  final String note;

  final int version;
  final DateTime? updatedAt;

  factory Todo.fromRow(Row row) {
    return Todo(
      id: row['id'] as String,
      title: row['title'] as String,
      completed: (row['completed'] as int? ?? 0) == 1,
      priority: row['priority'] as int? ?? 0,
      dueDate: _dateTimeOrNull(row['due_date']),
      startMinutes: row['start_time'] as int?,
      endMinutes: row['end_time'] as int?,
      hiddenInCalendar: (row['hidden_in_calendar'] as int? ?? 0) == 1,
      categoryIds: decodeCategoryIds(row['category_ids']),
      colorIndex: row['color_index'] as int?,
      recurrenceRule: (row['recurrence_rule'] as String?) ?? '',
      reminderLeads: decodeReminderLeads(row['reminder_leads']),
      reminderSound: _boolOrNull(row['reminder_sound']),
      location: (row['location'] as String?) ?? '',
      note: (row['note'] as String?) ?? '',
      version: row['version'] as int? ?? 1,
      updatedAt: _dateTimeOrNull(row['updated_at']),
    );
  }

  Map<String, Object?> toParams() {
    return {
      'id': id,
      'title': title,
      'completed': completed ? 1 : 0,
      'priority': priority,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'start_time': startMinutes,
      'end_time': endMinutes,
      'hidden_in_calendar': hiddenInCalendar ? 1 : 0,
      'category_ids': encodeCategoryIds(categoryIds),
      'color_index': colorIndex,
      'recurrence_rule': recurrenceRule,
      'reminder_leads': encodeReminderLeads(reminderLeads),
      'reminder_sound': reminderSound == null ? null : (reminderSound! ? 1 : 0),
      'location': location,
      'note': note,
      'version': version,
      // Il clock viaggia col record: serve al sync, e per un insert resta fuori
      // (lo mette il database col suo default).
      if (updatedAt != null) 'updated_at': updatedAt!.millisecondsSinceEpoch,
    };
  }

  static const Object _unset = Object();
  static const Object _unsetColor = Object();

  Todo copyWith({
    String? title,
    bool? completed,
    int? priority,
    Object? dueDate = _unset,
    Object? startMinutes = _unset,
    Object? endMinutes = _unset,
    bool? hiddenInCalendar,
    List<String>? categoryIds,
    Object? colorIndex = _unsetColor,
    String? recurrenceRule,
    Object? reminderLeads = _unset,
    Object? reminderSound = _unset,
    String? location,
    String? note,
    int? version,
    DateTime? updatedAt,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      startMinutes: identical(startMinutes, _unset)
          ? this.startMinutes
          : startMinutes as int?,
      endMinutes:
          identical(endMinutes, _unset) ? this.endMinutes : endMinutes as int?,
      hiddenInCalendar: hiddenInCalendar ?? this.hiddenInCalendar,
      categoryIds: categoryIds ?? this.categoryIds,
      colorIndex: identical(colorIndex, _unsetColor)
          ? this.colorIndex
          : colorIndex as int?,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      reminderLeads: identical(reminderLeads, _unset)
          ? this.reminderLeads
          : reminderLeads as List<int>?,
      reminderSound: identical(reminderSound, _unset)
          ? this.reminderSound
          : reminderSound as bool?,
      location: location ?? this.location,
      note: note ?? this.note,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _dateTimeOrNull(Object? millis) {
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis as int);
  }

  /// Il suono è a tre stati, quindi `null` (eredita) va distinto da 0 (spento).
  static bool? _boolOrNull(Object? value) =>
      value == null ? null : (value as int) == 1;
}
