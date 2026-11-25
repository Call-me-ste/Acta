import 'package:flutter/material.dart';

import '../../features/notes/note_blocks.dart';

/// Un blocco mentre lo si scrive: tipo, testo e i controller del widget.
class NoteDraftBlock {
  NoteDraftBlock({
    required this.id,
    required this.kind,
    this.indent = 0,
    this.text = '',
    this.checked = false,
    this.number,
    this.format = plainNoteFormat,
  })  : controller = TextEditingController(text: text),
        focus = FocusNode();

  final int id;
  NoteBlockKind kind;
  int indent;
  String text;
  bool checked;
  int? number;
  NoteTextFormat format;
  final TextEditingController controller;
  final FocusNode focus;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}
