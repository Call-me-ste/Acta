import 'dart:async';
import 'package:flutter/material.dart';

import '../../features/notes/note_blocks.dart';
import '../../theme/design_tokens.dart';
import 'note_block_row.dart';
import 'note_draft_block.dart';
import 'note_history.dart';
import 'note_serializer.dart';

part 'note_attachment_blocks.dart';

/// Editor a blocchi con salvataggio in Markdown.
class NoteBlockEditor extends StatefulWidget {
  const NoteBlockEditor({
    super.key,
    required this.initialText,
    required this.onChanged,
    this.onHistory,
    this.onListIndentChanged,
    this.attachmentBuilder,
  });

  final String initialText;
  final ValueChanged<String> onChanged;
  final void Function(bool canUndo, bool canRedo)? onHistory;
  final ValueChanged<int?>? onListIndentChanged;
  final Widget Function(String id, VoidCallback remove)? attachmentBuilder;

  @override
  State<NoteBlockEditor> createState() => NoteBlockEditorState();
}

class NoteBlockEditorState extends State<NoteBlockEditor> {
  final List<NoteDraftBlock> _blocks = [];
  var _nextId = 1;
  int? _corrente;
  bool _splitting = false;
  late final NoteHistory _cronologia;
  Timer? _timerStorico;
  bool _applicando = false;

  bool get canUndo => _cronologia.canUndo;
  bool get canRedo => _cronologia.canRedo;

  @override
  void initState() {
    super.initState();
    final parsed = parseNoteBlocks(widget.initialText);
    if (parsed.isEmpty) {
      _blocks.add(_crea(NoteBlockKind.paragraph));
    } else {
      for (final blocco in parsed) {
        final b = _crea(
          blocco.kind,
          indent: blocco.indent,
          text: blocco.text,
          checked: blocco.checked,
          number: blocco.number,
          format: blocco.format,
        );
        _blocks.add(b);
      }
    }
    _cronologia = NoteHistory(serializeDraft(_blocks));
    _notificaStorico();
    _notificaRientro();
  }

  @override
  void dispose() {
    _timerStorico?.cancel();
    for (final blocco in _blocks) {
      blocco.dispose();
    }
    super.dispose();
  }

  void _notificaStorico() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onHistory?.call(canUndo, canRedo);
    });
  }

  void _notificaRientro() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final block = _bloccoCorrente;
      widget.onListIndentChanged?.call(
        block != null && block.focus.hasFocus && _isList(block)
            ? block.indent
            : null,
      );
    });
  }

  bool _isList(NoteDraftBlock block) =>
      block.kind == NoteBlockKind.checkbox ||
      block.kind == NoteBlockKind.bullet ||
      block.kind == NoteBlockKind.numbered;

  void _programmaStorico() {
    if (_applicando) return;
    _timerStorico?.cancel();
    _timerStorico = Timer(AppMotion.history, _registra);
  }

  void _registra() {
    _timerStorico?.cancel();
    if (_applicando) return;
    _cronologia.record(serializeDraft(_blocks));
    _notificaStorico();
  }

  void undo() {
    _timerStorico?.cancel();
    final stato = _cronologia.undo();
    if (stato != null) _applica(stato);
    _notificaStorico();
  }

  void redo() {
    _timerStorico?.cancel();
    final stato = _cronologia.redo();
    if (stato != null) _applica(stato);
    _notificaStorico();
  }

  void _applica(String stato) {
    _applicando = true;
    final vecchi = List<NoteDraftBlock>.of(_blocks);
    _blocks.clear();
    for (final blocco in parseNoteBlocks(stato)) {
      _blocks.add(_crea(
        blocco.kind,
        indent: blocco.indent,
        text: blocco.text,
        checked: blocco.checked,
        number: blocco.number,
        format: blocco.format,
      ));
    }
    _corrente = null;
    setState(() {});
    _notificaRientro();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final blocco in vecchi) {
        blocco.dispose();
      }
    });
    widget.onChanged(stato);
    _applicando = false;
  }

  NoteDraftBlock _crea(
    NoteBlockKind kind, {
    int indent = 0,
    String text = '',
    bool checked = false,
    int? number,
    NoteTextFormat format = plainNoteFormat,
  }) {
    final blocco = NoteDraftBlock(
      id: _nextId++,
      kind: kind,
      indent: indent,
      text: text,
      checked: checked,
      number: number,
      format: format,
    );
    blocco.controller.text = text;
    blocco.focus.addListener(() {
      if (blocco.focus.hasFocus) {
        setState(() => _corrente = blocco.id);
      }
      if (mounted) _notificaRientro();
    });
    return blocco;
  }

  NoteDraftBlock? get _bloccoCorrente {
    for (final blocco in _blocks) {
      if (blocco.id == _corrente) return blocco;
    }
    return _blocks.isEmpty ? null : _blocks.first;
  }

  void _notifica() => widget.onChanged(serializeDraft(_blocks));

  void _modifica(VoidCallback action) => setState(action);

  void convert(NoteBlockKind kind) {
    final b = _bloccoCorrente;
    if (b == null || b.kind == NoteBlockKind.attachment) return;
    setState(() {
      if (b.kind == kind) {
        b.kind = NoteBlockKind.paragraph;
        b.indent = 0;
      } else {
        b.kind = kind;
        if (kind == NoteBlockKind.numbered) {
          b.number ??= nextNumber(_blocks);
        }
        if (kind == NoteBlockKind.checkbox) b.checked = false;
        if (kind == NoteBlockKind.heading) b.indent = 0;
      }
    });
    _notifica();
    _registra();
    _fuoco(b, b.text.length);
    _notificaRientro();
  }

  void indent(int delta) {
    final b = _bloccoCorrente;
    if (b == null || !b.focus.hasFocus || !_isList(b)) return;
    final livello = (b.indent + delta).clamp(0, 3);
    if (livello == b.indent) return;
    if (_timerStorico?.isActive ?? false) _registra();
    setState(() => b.indent = livello);
    _notifica();
    _registra();
    _notificaRientro();
  }

  void _fuoco(NoteDraftBlock b, int offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      b.focus.requestFocus();
      b.controller.selection = TextSelection.collapsed(
          offset: offset.clamp(0, b.controller.text.length));
    });
  }

  void _onChanged(NoteDraftBlock b, String valore) {
    if (_splitting) return;
    final aCapo = valore.indexOf('\n');
    if (aCapo < 0) {
      b.text = valore;
      _notifica();
      _programmaStorico();
      return;
    }

    _splitting = true;
    final sinistra = valore.substring(0, aCapo);
    final destra = valore.substring(aCapo + 1);
    b.text = sinistra;
    b.controller.value = TextEditingValue(
      text: sinistra,
      selection: TextSelection.collapsed(offset: sinistra.length),
    );

    final nuovaKind =
        b.kind == NoteBlockKind.heading ? NoteBlockKind.paragraph : b.kind;
    final nuovo = _crea(
      nuovaKind,
      indent: b.indent,
      text: destra,
      number: nuovaKind == NoteBlockKind.numbered ? (b.number ?? 0) + 1 : null,
      format: b.format,
    );
    setState(() => _blocks.insert(_blocks.indexOf(b) + 1, nuovo));
    _splitting = false;
    _notifica();
    _registra();
    _fuoco(nuovo, 0);
  }

  void _spunta(NoteDraftBlock b, bool valore) {
    setState(() => b.checked = valore);
    _notifica();
    _registra();
  }

  void _unisciAlPrecedente(NoteDraftBlock b) {
    final indice = _blocks.indexOf(b);
    if (indice <= 0) return;
    final precedente = _blocks[indice - 1];
    if (precedente.kind == NoteBlockKind.attachment) return;
    final punto = precedente.controller.text.length;
    precedente.text = precedente.controller.text + b.controller.text;
    precedente.controller.value = TextEditingValue(
      text: precedente.text,
      selection: TextSelection.collapsed(offset: precedente.text.length),
    );
    setState(() => _blocks.removeAt(indice));
    // Il widget della riga sparisce in questo frame: si libera dopo.
    WidgetsBinding.instance.addPostFrameCallback((_) => b.dispose());
    _notifica();
    _registra();
    _fuoco(precedente, punto);
  }

  @override
  Widget build(BuildContext context) => _buildBlocks(context);
}
