part of 'note_block_editor.dart';

extension NoteAttachmentBlocks on NoteBlockEditorState {
  void formatText({NoteInk? ink, bool highlight = false}) {
    final block = _bloccoCorrente;
    if (block == null || block.kind == NoteBlockKind.attachment) return;
    final next = highlight
        ? (ink: block.format.ink, highlighted: !block.format.highlighted)
        : (ink: ink, highlighted: block.format.highlighted);
    if (next == block.format) return;
    if (_timerStorico?.isActive ?? false) _registra();
    _modifica(() => block.format = next);
    _notifica();
    _registra();
  }

  void insertAttachments(List<String> ids) {
    if (ids.isEmpty) return;
    var current = _bloccoCorrente;
    if (current != null && current.kind == NoteBlockKind.attachment) {
      current = null;
    }
    final index = current == null ? _blocks.length : _blocks.indexOf(current);
    final selection = current?.controller.selection;
    final offset = selection != null && selection.isValid
        ? selection.extentOffset.clamp(0, current!.text.length)
        : current?.text.length ?? 0;
    final attachments = [
      for (final id in ids) _crea(NoteBlockKind.attachment, text: id),
    ];
    _modifica(() {
      if (current == null) {
        _blocks.addAll([...attachments, _crea(NoteBlockKind.paragraph)]);
      } else if (offset == 0) {
        _blocks.insertAll(index, attachments);
      } else {
        final rest = current.text.substring(offset);
        current.text = current.text.substring(0, offset);
        current.controller.text = current.text;
        _blocks.insertAll(index + 1, [
          ...attachments,
          _crea(NoteBlockKind.paragraph, text: rest, format: current.format),
        ]);
      }
    });
    _notifica();
    _registra();
  }

  void _removeAttachment(NoteDraftBlock block) {
    _modifica(() {
      _blocks.remove(block);
      if (_blocks.isEmpty) _blocks.add(_crea(NoteBlockKind.paragraph));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => block.dispose());
    _notifica();
    _registra();
  }

  Widget _buildBlocks(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('note-content'),
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      itemCount: _blocks.length,
      itemBuilder: (context, index) {
        final b = _blocks[index];
        if (b.kind == NoteBlockKind.attachment) {
          return KeyedSubtree(
            key: ValueKey(b.id),
            child: widget.attachmentBuilder
                    ?.call(b.text, () => _removeAttachment(b)) ??
                const ListTile(title: Text('Allegato non disponibile')),
          );
        }
        return NoteBlockRow(
          id: b.id,
          kind: b.kind,
          indent: b.indent,
          controller: b.controller,
          focusNode: b.focus,
          checked: b.checked,
          number: b.number,
          format: b.format,
          hint: index == 0 && b.text.isEmpty ? 'Inizia a scrivere…' : null,
          onChanged: (valore) {
            _corrente = b.id;
            _onChanged(b, valore);
          },
          onChecked: (valore) => _spunta(b, valore),
          onFocus: () => _corrente = b.id,
          onBackspaceAtStart: () => _unisciAlPrecedente(b),
        );
      },
    );
  }
}
