import '../../features/notes/note_blocks.dart';
import 'note_draft_block.dart';

/// Dal modello dell'editor al markdown: un solo posto, così l'autosave e la
/// cronologia salvano esattamente la stessa cosa.
String serializeDraft(List<NoteDraftBlock> blocks) {
  final righe = <String>[];
  for (final b in blocks) {
    final pad = '  ' * b.indent;
    final text = formatNoteLine(b.text, b.format);
    switch (b.kind) {
      case NoteBlockKind.paragraph:
        righe.add(text);
      case NoteBlockKind.heading:
        righe.add('# $text');
      case NoteBlockKind.bullet:
        righe.add('$pad- $text');
      case NoteBlockKind.numbered:
        righe.add('$pad${b.number ?? 1}. $text');
      case NoteBlockKind.checkbox:
        righe.add('$pad- [${b.checked ? 'x' : ' '}]'
            '${text.isEmpty ? '' : ' $text'}');
      case NoteBlockKind.attachment:
        righe.add(attachmentLine(b.text));
    }
  }
  return righe.join('\n');
}

/// Il prossimo numero per un elenco numerato.
int nextNumber(List<NoteDraftBlock> blocks) {
  var massimo = 0;
  for (final b in blocks) {
    if (b.kind == NoteBlockKind.numbered && (b.number ?? 0) > massimo) {
      massimo = b.number!;
    }
  }
  return massimo + 1;
}
