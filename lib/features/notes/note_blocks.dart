enum NoteBlockKind {
  paragraph,
  heading,
  bullet,
  numbered,
  checkbox,
  attachment
}

enum NoteInk { blue, green, red, purple }

typedef NoteTextFormat = ({NoteInk? ink, bool highlighted});
const plainNoteFormat = (ink: null as NoteInk?, highlighted: false);

final _formatSuffix =
    RegExp(r'<!--planner-text:v1:(-|blue|green|red|purple):([01])-->$');

String formatNoteLine(String text, NoteTextFormat format) {
  if (format == plainNoteFormat) return text;
  return '$text<!--planner-text:v1:${format.ink?.name ?? '-'}:${format.highlighted ? 1 : 0}-->';
}

String stripNoteFormat(String text) => text.replaceFirst(_formatSuffix, '');

final _attachment = RegExp(r'^!\[\]\(attachment:([a-f0-9-]{36})\)$');

String attachmentLine(String id) => '![](attachment:$id)';
bool isAttachmentLine(String line) => _attachment.hasMatch(line);

Set<String> attachmentIds(String body) => {
      for (final line in body.split('\n'))
        if (_attachment.firstMatch(line) case final match?) match.group(1)!,
    };

class NoteBlock {
  const NoteBlock({
    required this.kind,
    required this.text,
    required this.line,
    this.checked = false,
    this.number,
    this.indent = 0,
    this.level = 1,
    this.format = plainNoteFormat,
  });

  final NoteBlockKind kind;
  final String text;
  final int line;
  final bool checked;
  final int? number;

  /// Rientro in livelli (2 spazi per livello) per elenchi e checklist.
  final int indent;

  /// Livello del titolo: 1 = `#`, 2 = `##`, 3 = `###`.
  final int level;
  final NoteTextFormat format;
}

final RegExp _heading = RegExp(r'^(#{1,3})\s+(.*)$');
final RegExp _checkbox = RegExp(r'^(\s*)-\s*\[([ xX])\]\s?(.*)$');
final RegExp _bullet = RegExp(r'^(\s*)[-•]\s+(.*)$');
final RegExp _numbered = RegExp(r'^(\s*)(\d+)\.\s+(.*)$');
final RegExp _marcatore = RegExp(
  r'^\s*(?:#{1,3}\s+|-\s*\[[ xX]\]\s?|- |• |\d+\.\s+)',
);

int _indentOf(String spaces) => (spaces.length ~/ 2).clamp(0, 3);

List<NoteBlock> parseNoteBlocks(String content) {
  final righe = content.split('\n');
  final blocchi = <NoteBlock>[];
  for (var i = 0; i < righe.length; i++) {
    final attachment = _attachment.firstMatch(righe[i]);
    if (attachment != null) {
      blocchi.add(NoteBlock(
        kind: NoteBlockKind.attachment,
        text: attachment.group(1)!,
        line: i,
      ));
      continue;
    }
    final marker = _formatSuffix.firstMatch(righe[i]);
    final NoteTextFormat format = marker == null
        ? plainNoteFormat
        : (
            ink: marker.group(1) == '-'
                ? null
                : NoteInk.values.byName(marker.group(1)!),
            highlighted: marker.group(2) == '1',
          );
    final riga =
        marker == null ? righe[i] : righe[i].substring(0, marker.start);
    final titolo = _heading.firstMatch(riga);
    if (titolo != null) {
      blocchi.add(NoteBlock(
        kind: NoteBlockKind.heading,
        text: titolo.group(2) ?? '',
        line: i,
        level: titolo.group(1)!.length,
        format: format,
      ));
      continue;
    }
    final check = _checkbox.firstMatch(riga);
    if (check != null) {
      blocchi.add(NoteBlock(
        kind: NoteBlockKind.checkbox,
        text: check.group(3) ?? '',
        line: i,
        checked: check.group(2)!.toLowerCase() == 'x',
        indent: _indentOf(check.group(1) ?? ''),
        format: format,
      ));
      continue;
    }
    final numero = _numbered.firstMatch(riga);
    if (numero != null) {
      blocchi.add(NoteBlock(
        kind: NoteBlockKind.numbered,
        text: numero.group(3) ?? '',
        line: i,
        number: int.tryParse(numero.group(2)!) ?? 1,
        indent: _indentOf(numero.group(1) ?? ''),
        format: format,
      ));
      continue;
    }
    final punto = _bullet.firstMatch(riga);
    if (punto != null) {
      blocchi.add(NoteBlock(
        kind: NoteBlockKind.bullet,
        text: punto.group(2) ?? '',
        line: i,
        indent: _indentOf(punto.group(1) ?? ''),
        format: format,
      ));
      continue;
    }
    blocchi.add(NoteBlock(
      kind: NoteBlockKind.paragraph,
      text: riga,
      line: i,
      format: format,
    ));
  }
  return blocchi;
}

/// Spunta o toglie la spunta a una riga checkbox, lasciando il resto uguale.
String toggleCheckbox(String content, int line, bool checked) {
  final righe = content.split('\n');
  if (line < 0 || line >= righe.length) return content;
  final match = _checkbox.firstMatch(righe[line]);
  if (match == null) return content;
  final spazi = match.group(1) ?? '';
  righe[line] = '$spazi- [${checked ? 'x' : ' '}] ${match.group(3) ?? ''}';
  return righe.join('\n');
}

/// Inserisce (o sostituisce) il marcatore all'inizio della riga del cursore.
String prefissaRiga(String content, int cursor, String prefisso) {
  final limite = cursor.clamp(0, content.length);
  final inizio = limite == 0 ? 0 : content.lastIndexOf('\n', limite - 1) + 1;
  final fineTrovata = content.indexOf('\n', limite);
  final fine = fineTrovata == -1 ? content.length : fineTrovata;
  final riga = content.substring(inizio, fine);
  final pulita = riga.replaceFirst(_marcatore, '');
  final nuova = '$prefisso$pulita';
  return content.replaceRange(inizio, fine, nuova);
}
