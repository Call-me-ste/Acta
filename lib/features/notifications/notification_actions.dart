import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/database/database_service.dart';
import '../../core/database/occurrence_commands.dart';
import '../../core/sync/hash.dart';
import '../events/domain/event.dart';
import '../recurrence/domain/recurrence_expansion.dart';
import '../recurrence/domain/recurrence_rule.dart';
import '../todos/domain/todo.dart';
import 'domain/reminder_plan.dart';
import 'notification_settings_controller.dart';

const notificationSnoozeAction = 'rimanda-10';
const notificationDoneAction = 'segna-fatto';
const notificationCompletionClock = 'notificationCompletion';
const _snoozePrefix = 'notificationSnooze:';
const _durataRinvio = Duration(minutes: 10);
const _tolleranzaConsegna = Duration(minutes: 15);
const _baseIdRinvio = 1000000000;

bool idDiRinvio(int id) =>
    id >= _baseIdRinvio && id < _baseIdRinvio + 0x10000000;

class NotificationTarget {
  const NotificationTarget(this.entity, this.id, this.date);

  final String entity;
  final String id;
  final DateTime date;

  DateTime get day => DateTime(date.year, date.month, date.day);
  String get key => '$entity:$id@${day.millisecondsSinceEpoch}';

  static NotificationTarget? parse(String? payload) {
    if (payload == null) return null;
    final parts = payload.split('@');
    if (parts.length < 4) return null;
    final name = parts.first;
    final millis = int.tryParse(parts[3]);
    if (millis == null || millis.abs() > 8640000000000000) return null;
    final colon = name.indexOf(':');
    if (colon < 0 || colon == name.length - 1) return null;
    final entity = switch (name.substring(0, colon)) {
      'evento' => 'event',
      'todo' => 'todo',
      _ => null,
    };
    if (entity == null) return null;
    return NotificationTarget(
      entity,
      name.substring(colon + 1),
      DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }
}

class NotificationActions {
  const NotificationActions(this._db);

  final DatabaseService _db;

  Todo? _todo(NotificationTarget target) {
    final row = _db.instance
        .select('SELECT * FROM todos WHERE id = ?', [target.id]).firstOrNull;
    if (row == null) return null;
    final todo = Todo.fromRow(row);
    if (todo.completed ||
        !_cadeIl(todo.dueDate, todo.recurrenceRule, target.day)) {
      return null;
    }
    if (_db.occurrences.isDone(todo.id, target.day)) return null;
    return todo;
  }

  bool _cadeIl(DateTime? start, String raw, DateTime day) {
    if (start == null) return false;
    final rule = RecurrenceRule.tryParse(raw);
    if (rule == null) {
      return DateTime(start.year, start.month, start.day) == day;
    }
    return expandOccurrences(rule, start: start, rangeStart: day, rangeEnd: day)
        .isNotEmpty;
  }

  bool completa(NotificationTarget target) {
    if (target.entity != 'todo') return false;
    var completato = false;
    _db.runInTransaction(() {
      final todo = _todo(target);
      if (todo == null) return;
      final op = const Uuid().v4();
      if (todo.recurrenceRule.isNotEmpty) {
        _db.markOccurrenceDoneInTransaction(
          itemId: target.id,
          day: target.day,
          operationId: op,
        );
        _db.meta.set(notificationCompletionClock, op);
        completato = true;
        return;
      }
      final ora = DateTime.now();
      final next = todo.copyWith(
          completed: true, version: todo.version + 1, updatedAt: ora);
      final params = next.toParams();
      _db.updateTodo(params);
      _db.outbox.enqueue(
        operationId: op,
        entity: 'todo',
        entityId: todo.id,
        operation: 'upsert',
        version: next.version,
        updatedAt: ora.millisecondsSinceEpoch,
        payload: params,
      );
      _db.meta.set(notificationCompletionClock, op);
      completato = true;
    });
    return completato;
  }

  bool rimanda(NotificationTarget target, String payload, DateTime ora,
      NotificationSettingsController impostazioni) {
    var salvato = false;
    _db.runInTransaction(() {
      final clock = _db.entities.localClock(target.entity, target.id);
      if (clock == null) return;
      final quando = ora.add(_durataRinvio);
      if (_avviso(target, quando, impostazioni) == null) return;
      _db.meta.set(
          '$_snoozePrefix${target.key}',
          jsonEncode([
            payload,
            quando.millisecondsSinceEpoch,
            clock.$1,
            clock.$2,
          ]));
      salvato = true;
    });
    return salvato;
  }

  List<ScheduledReminder> rinvii(
      DateTime ora, NotificationSettingsController impostazioni) {
    final result = <ScheduledReminder>[];
    final rows = _db.instance.select(
      'SELECT key, value FROM sync_meta WHERE key LIKE ?',
      ['$_snoozePrefix%'],
    );
    for (final row in rows) {
      final raw = row['value'] as String;
      final data = jsonDecode(raw);
      final target = NotificationTarget.parse(data[0] as String);
      final when = DateTime.fromMillisecondsSinceEpoch(data[1] as int);
      final clock = target == null
          ? null
          : _db.entities.localClock(target.entity, target.id);
      final avviso = target != null &&
              !when.add(_tolleranzaConsegna).isBefore(ora) &&
              clock == (data[2], data[3])
          ? _avviso(target, when, impostazioni)
          : null;
      if (avviso != null) {
        result.add(avviso);
      } else {
        _db.instance.execute(
            'DELETE FROM sync_meta WHERE key = ? AND value = ?',
            [row['key'], raw]);
      }
    }
    return result;
  }

  ScheduledReminder? _avviso(
    NotificationTarget target,
    DateTime when,
    NotificationSettingsController impostazioni,
  ) {
    final hash = fnv1a64Hex(target.key.codeUnits);
    final id = _baseIdRinvio + int.parse(hash.substring(0, 7), radix: 16);
    final quietHours = impostazioni.quietHours;
    final quiet = quietHours != null && isQuiet(when, quietHours);

    if (target.entity == 'todo') {
      if (!impostazioni.todoAttivo) return null;
      final todo = _todo(target);
      if (todo == null || (todo.reminderLeads?.isEmpty ?? false)) return null;
      return ScheduledReminder(
        id: id,
        itemId: todo.id,
        when: when,
        title: todo.title,
        kind: ReminderKind.todo,
        sound: todo.reminderSound ?? impostazioni.suona,
        quiet: quiet,
        itemDate: target.date,
        hasTime: todo.startMinutes != null,
        location: todo.location,
      );
    }

    final row = _db.instance
        .select('SELECT * FROM events WHERE id = ?', [target.id]).firstOrNull;
    if (row == null) return null;
    final event = Event.fromRow(row);
    final attivo = event.allDay
        ? impostazioni.tuttoIlGiornoAttivo
        : impostazioni.eventoAttivo;
    if (!attivo ||
        (event.reminderLeads?.isEmpty ?? false) ||
        !_cadeIl(event.start, event.recurrenceRule, target.day) ||
        _db.occurrences.isDone(event.id, target.day)) {
      return null;
    }

    return ScheduledReminder(
      id: id,
      itemId: event.id,
      when: when,
      title: event.title,
      kind: event.allDay ? ReminderKind.tuttoIlGiorno : ReminderKind.evento,
      sound: event.reminderSound ?? impostazioni.suona,
      quiet: quiet,
      itemDate: target.date,
      hasTime: !event.allDay,
      location: event.location,
    );
  }
}
