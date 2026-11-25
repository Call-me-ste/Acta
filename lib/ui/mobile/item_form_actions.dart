part of 'item_form.dart';

/// Le azioni del form, estratte per tenere `item_form.dart` sotto le 300 righe.
/// La part condivide lo stato: qui si legge e si scrive lo stesso `_ItemFormState`.
extension _ItemFormActions on _ItemFormState {
  Future<void> _pickDay({required bool isStart}) async {
    final picked = await askItemDay(context, isStart ? _day : _endDay);
    if (picked == null || !mounted) return;
    aggiorna(() {
      if (isStart) {
        final days = DateTime.utc(_endDay.year, _endDay.month, _endDay.day)
            .difference(DateTime.utc(_day.year, _day.month, _day.day))
            .inDays;
        _day = dateOnly(picked);
        _endDay = DateTime(picked.year, picked.month, picked.day + days);
      } else {
        _endDay = dateOnly(picked);
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await askItemTime(context,
        start: _start, end: _end, isStart: isStart, sameDay: _day == _endDay);
    if (picked == null || !mounted) return;
    aggiorna(() {
      _start = picked.start;
      _end = picked.end;
    });
  }

  bool _sameEventBounds(Event? event) =>
      event != null &&
      _day == dateOnly(event.start) &&
      _endDay == dateOnly(event.end) &&
      _start == TimeOfDay.fromDateTime(event.start) &&
      _end == TimeOfDay.fromDateTime(event.end) &&
      _allDay == event.allDay;

  void _tornaIndietro() {
    if (_title.text.trim().isEmpty) {
      Navigator.pop(context);
    } else {
      _save(daIndietro: true);
    }
  }

  Future<void> _save({bool daIndietro = false}) async {
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      aggiorna(() => _error = 'Serve un titolo');
      return;
    }

    aggiorna(() {
      _saving = true;
      _error = null;
    });
    final error = await saveItem(
      context,
      ItemDraft(
        isEvent: _type == ItemType.evento,
        title: title,
        day: _day,
        endDay: _endDay,
        keepEventBounds: _sameEventBounds(widget.event),
        startMinutes: minutesOfDay(_start),
        endMinutes: minutesOfDay(_end),
        allDay: _allDay,
        priority: _todo.priority,
        dueDate: _todo.dueDate,
        todoStartMinutes: _todo.startMinutes,
        todoEndMinutes: _todo.endMinutes,
        colorIndex: _colorIndex,
        colorHex: _colorHex,
        recurrenceRule: _rule?.toRuleString() ?? '',
        categoryIds: _categoryIds,
        location: _location,
        note: _note,
        reminderLeads: _leads,
        reminderSound: _sound,
      ),
      event: widget.event,
      todo: widget.todo,
    ).catchError((Object error) {
      return isDeviceStorageFull(error)
          ? deviceStorageFullMessage
          : 'Impossibile salvare. Riprova.';
    });

    if (!mounted) return;
    if (error != null) {
      aggiorna(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context);
    if (daIndietro) {
      messenger?.showSnackBar(SnackBar(
        content:
            Text(_type == ItemType.evento ? 'Evento salvato' : 'To do salvato'),
      ));
    }
  }

  Future<void> _delete() async {
    final deleted = await deleteFromForm(
      context,
      title: _title.text,
      isEvent: _type == ItemType.evento,
      event: widget.event,
      todo: widget.todo,
    );
    if (deleted && mounted) Navigator.pop(context);
  }

  /// La prima categoria con un colore diventa il default dell'elemento, se
  /// l'utente non ha già scelto un colore a mano.
  void _cambiaCategorie(List<String> ids) {
    aggiorna(() {
      _categoryIds = ids;
      if (_coloreSceltoAMano) return;
      final colore = coloreDellaCategoria(
        evento: _type == ItemType.evento,
        categorie: context.read<CategoryController>().byIds(ids),
      );
      if (colore != null) {
        _colorIndex = colore.index;
        _colorHex = colore.hex;
      }
    });
  }
}
