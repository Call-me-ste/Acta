import 'package:flutter/material.dart';

import '../../features/notes/note_blocks.dart';

TextStyle? noteTextStyle(
    ThemeData theme, TextStyle? base, NoteTextFormat format) {
  if (format == plainNoteFormat) return base;
  final dark = theme.brightness == Brightness.dark;
  final color = switch (format.ink) {
    NoteInk.blue => dark ? const Color(0xffa9cbff) : const Color(0xff124e9a),
    NoteInk.green => dark ? const Color(0xffa4dfaa) : const Color(0xff1b6029),
    NoteInk.red => dark ? const Color(0xffffb4ac) : const Color(0xff942722),
    NoteInk.purple => dark ? const Color(0xffddc0ff) : const Color(0xff65348d),
    null => null,
  };
  return (base ?? const TextStyle()).copyWith(
    color: color,
    backgroundColor: format.highlighted
        ? (dark ? const Color(0xff53451b) : const Color(0xffffed99))
        : null,
  );
}
