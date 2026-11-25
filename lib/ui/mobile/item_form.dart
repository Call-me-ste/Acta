import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/categories/category_controller.dart';
import '../../features/events/domain/event.dart';
import '../../features/notes/note_provider.dart';
import '../../features/notifications/notification_settings_controller.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../features/todos/domain/todo.dart';
import '../../core/database/database_service.dart';
import '../../core/storage_failure.dart';
import '../../theme/design_tokens.dart';
import '../shared/date_math.dart';
import '../shared/formatters.dart';
import 'item_common_fields.dart';
import 'item_delete.dart';
import 'item_form_color.dart';
import 'item_form_header.dart';
import 'item_picking.dart';
import 'item_details_fields.dart';
import 'item_save.dart';
import 'note_links_indicator.dart';
import 'item_todo_part.dart';
import 'item_type.dart';
import 'item_type_section.dart';

part 'item_form_actions.dart';

/// Il form di creazione/modifica, **uno solo** per eventi e todo.
///
/// Lo stato sta tutto qui (anche quello delle due sezioni): cambiando tipo si
/// perde solo ciò che si vede, non ciò che si è scritto. Salvataggio e
/// validazione e cancellazione stanno in `item_save.dart`/`item_delete.dart`.
class ItemForm extends StatefulWidget {
  const ItemForm({
    super.key,
    required this.type,
    required this.day,
    this.event,
    this.todo,
    this.noteProvider,
    this.initialTitle,
    this.initialNote,
  });

  final ItemType type;
  final DateTime day;
  final Event? event;
  final Todo? todo;
  final String? initialTitle;
  final String? initialNote;
  final NoteProvider? noteProvider;
  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  late final TextEditingController _title;
  late ItemType _type;

  int? _colorIndex;
  String? _colorHex;
  bool _coloreSceltoAMano = false;
  RecurrenceRule? _rule;
  late List<String> _categoryIds;

  late DateTime _day;
  late DateTime _endDay;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late bool _allDay;

  late ParteTodo _todo;

  late String _location;
  late String _note;
  List<int>? _leads;
  bool? _sound;

  late final List<String> _usedPlaces;

  String? _error;
  bool _saving = false;

  /// Ponte per l'estensione in item_form_actions.dart.
  void aggiorna(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final todo = widget.todo;

    _type = event != null
        ? ItemType.evento
        : todo != null
            ? ItemType.todo
            : widget.type;
    _title = TextEditingController(
      text: event?.title ?? todo?.title ?? widget.initialTitle ?? '',
    );
    _colorIndex = event?.colorIndex ?? todo?.colorIndex;
    _colorHex = event?.colorHex;
    _coloreSceltoAMano = _colorHex != null;
    _rule = RecurrenceRule.tryParse(
      event?.recurrenceRule ?? todo?.recurrenceRule,
    );
    _categoryIds = List<String>.of(
      event?.categoryIds ?? todo?.categoryIds ?? const <String>[],
    );

    _day = dateOnly(event?.start ?? widget.day);
    _endDay = dateOnly(event?.end ?? _day);
    final (inizio, fine) = orarioEventoPredefinito(_day, DateTime.now());
    _start = event == null ? inizio : TimeOfDay.fromDateTime(event.start);
    _end = event == null ? fine : TimeOfDay.fromDateTime(event.end);
    _allDay = event?.allDay ?? false;

    _todo = ParteTodo.da(todo, giorno: widget.day);

    _location = event?.location ?? todo?.location ?? '';
    _note = widget.initialNote ?? event?.note ?? todo?.note ?? '';
    _leads = event?.reminderLeads ?? todo?.reminderLeads;
    _sound = event?.reminderSound ?? todo?.reminderSound;
    _usedPlaces =
        context.read<DatabaseService?>()?.places.usedPlaces() ?? const [];
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.event != null || widget.todo != null;
    final notifiche = context.read<NotificationSettingsController?>();
    final defaultLead = _type == ItemType.evento
        ? (notifiche?.anticipoEventi ??
            NotificationSettingsController.anticipoEventiDefault)
        : (notifiche?.anticipoTodo ??
            NotificationSettingsController.anticipoTodoDefault);
    final defaultSound =
        notifiche?.suono ?? NotificationSettingsController.suonoSistema;
    final allDayReminder = _type == ItemType.evento && _allDay;
    final tuttoIlGiorno = notifiche?.oraTuttoIlGiorno ??
        NotificationSettingsController.oraTuttoIlGiornoDefault;

    return PopScope(
      canPop: editing && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !editing && !_saving) _tornaIndietro();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: ItemFormHeader(
                editing: editing,
                type: _type,
                onType: (type) => setState(() => _type = type),
                onClose: _saving ? null : () => Navigator.pop(context),
                onSave: _saving ? null : _save,
              ),
            ),
            if (_error case final errore?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: Semantics(
                  liveRegion: true,
                  child: Text(errore,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.m,
                  AppSpacing.l,
                  AppSpacing.s,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ItemCommonFields(
                      title: _title,
                      colorIndex: _colorIndex ?? 0,
                      colorHex: _colorHex,
                      noneSelected:
                          _type == ItemType.todo && _colorIndex == null,
                      rule: _rule,
                      anchor: _type == ItemType.evento
                          ? _day
                          : _todo.dueDate ?? DateTime.now(),
                      categoryIds: _categoryIds,
                      onCategories: _cambiaCategorie,
                      autofocus: !editing && widget.initialTitle == null,
                      onIndex: (index) => setState(() {
                        _colorIndex = index;
                        _colorHex = null;
                        _coloreSceltoAMano = true;
                      }),
                      onCustom: _type == ItemType.evento
                          ? (hex) => setState(() {
                                _colorHex = hex;
                                _coloreSceltoAMano = true;
                              })
                          : null,
                      onNone: _type == ItemType.todo
                          ? () => setState(() {
                                _colorIndex = null;
                                _coloreSceltoAMano = true;
                              })
                          : null,
                      onRule: (rule) => setState(() => _rule = rule),
                      details: ItemDetailsFields(
                        leads: _leads,
                        sound: _sound,
                        onLeads: (leads) => setState(() => _leads = leads),
                        onSound: (sound) => setState(() => _sound = sound),
                        place: _location,
                        note: _note,
                        usedPlaces: _usedPlaces,
                        onPlace: (place) => _location = place,
                        onNote: (note) => _note = note,
                        defaultLeadMinutes: defaultLead,
                        fixedReminderTime: allDayReminder
                            ? 'Alle ${formatMinutes(tuttoIlGiorno)}'
                            : null,
                        defaultSound: defaultSound,
                      ),
                      child: ItemTypeSection(
                        type: _type,
                        day: _day,
                        endDay: _endDay,
                        allDay: _allDay,
                        start: _start,
                        end: _end,
                        onPickDay: () => _pickDay(isStart: true),
                        onPickEndDay: () => _pickDay(isStart: false),
                        onToggleAllDay: (value) =>
                            setState(() => _allDay = value),
                        onPickStart: () => _pickTime(isStart: true),
                        onPickEnd: () => _pickTime(isStart: false),
                        todo: _todo,
                        onTodo: (parte) => setState(() => _todo = parte),
                      ),
                    ),
                    if (editing && widget.noteProvider != null)
                      NoteLinksIndicator(
                        noteProvider: widget.noteProvider!,
                        entityType: widget.event != null ? 'event' : 'todo',
                        entityId: widget.event?.id ?? widget.todo!.id,
                      ),
                    if (editing)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _delete,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Elimina'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            minimumSize: const Size(0, AppSpacing.touchTarget),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
