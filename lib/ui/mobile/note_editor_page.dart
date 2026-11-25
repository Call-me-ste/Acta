import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/storage_failure.dart';
import '../../features/events/event_provider.dart';
import '../../features/notes/domain/note.dart';
import '../../features/notes/note_blocks.dart';
import '../../features/notes/note_attachment_store.dart';
import '../../features/notes/note_provider.dart';
import '../../features/todos/todo_provider.dart';
import '../../theme/design_tokens.dart';
import '../shared/confirm_delete.dart';
import 'note_block_editor.dart';
import 'note_attachment_tile.dart';
import 'note_attachment_picker.dart';
import 'note_editor_appbar.dart';
import 'note_editor_body.dart';
import 'note_editor_footer.dart';
import 'note_folder_picker.dart';
import 'note_links_section.dart';

part 'note_editor_layout.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({
    super.key,
    required this.note,
    this.eventi,
    this.todos,
    this.sharedAttachments = const [],
  });

  final Note note;

  final EventProvider? eventi;
  final TodoProvider? todos;
  final List<({String path, String name, NoteAttachmentKind kind})>
      sharedAttachments;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _title;
  late final ValueNotifier<String> _testoContenuto;
  late final Listenable _testo;
  final _editorKey = GlobalKey<NoteBlockEditorState>();
  final _listIndent = ValueNotifier<int?>(null);
  late Note _nota;
  late String _contenuto;
  bool _dirty = false;
  bool _salvato = false;
  bool _saveFailed = false;
  bool _anteprima = false;
  bool _canUndo = false;
  bool _canRedo = false;
  Timer? _autosave;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _nota = widget.note;
    _contenuto = widget.note.content;
    _title = TextEditingController(text: widget.note.title);
    _testoContenuto = ValueNotifier<String>(_contenuto);
    _testo = Listenable.merge([_title, _testoContenuto]);
    _title.addListener(_markDirty);
    if (widget.sharedAttachments.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _importShared();
      });
    }
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _listIndent.dispose();
    _title.dispose();
    _testoContenuto.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
    if (_salvato) setState(() => _salvato = false);
    _autosave?.cancel();
    _autosave = Timer(
      AppMotion.autosave,
      () {
        if (mounted) _salvaSenzaChiudere();
      },
    );
  }

  Future<bool> _salvaSenzaChiudere() async {
    _autosave?.cancel();
    final titolo = _title.text;
    final corpo = _contenuto;
    try {
      await context.read<NoteProvider>().updateNote(
            _nota.copyWith(title: titolo, content: corpo),
          );
    } catch (error) {
      if (mounted) {
        setState(() => _saveFailed = true);
        _allegatoMessaggio(isDeviceStorageFull(error)
            ? 'Nota non salvata. $deviceStorageFullMessage'
            : 'Nota non salvata. Riprova prima di uscire.');
      }
      return false;
    }
    if (!mounted) return false;
    _nota = context.read<NoteProvider>().byId(_nota.id) ?? _nota;
    setState(() {
      if (_title.text == titolo && _contenuto == corpo) {
        _dirty = false;
        _salvato = true;
        _saveFailed = false;
      }
    });
    return !_dirty;
  }

  void _onContenuto(String valore) {
    _contenuto = valore;
    _testoContenuto.value = valore;
    _markDirty();
  }

  void _storicoCambiato(bool canUndo, bool canRedo) {
    if (!mounted) return;
    if (_canUndo == canUndo && _canRedo == canRedo) return;
    setState(() {
      _canUndo = canUndo;
      _canRedo = canRedo;
    });
  }

  void _converti(NoteBlockKind tipo) => _editorKey.currentState?.convert(tipo);

  void _spunta(int line, bool checked) {
    setState(() {
      _contenuto = toggleCheckbox(_contenuto, line, checked);
      _testoContenuto.value = _contenuto;
    });
    _markDirty();
  }

  Future<void> _cambiaAnteprima() async {
    if (!_anteprima && _dirty && !await _salvaSenzaChiudere()) return;
    if (!mounted) return;
    setState(() => _anteprima = !_anteprima);
  }

  Future<void> _scegliCartella() async {
    final provider = context.read<NoteProvider>();
    final scelta = await scegliCartellaPerNota(
      context,
      provider,
      _nota.folderId,
    );
    if (scelta == null || !mounted) return;
    final base = _nota.copyWith(title: _title.text, content: _contenuto);
    await provider.moveNote(base, scelta == 'senza' ? null : scelta);
    if (!mounted) return;
    setState(() {
      _nota = provider.byId(_nota.id) ?? _nota;
      _salvato = true;
    });
  }

  Future<void> _togglePin() async {
    _nota = _nota.copyWith(pinned: !_nota.pinned);
    await context
        .read<NoteProvider>()
        .updateNote(_nota.copyWith(title: _title.text, content: _contenuto));
    if (!mounted) return;
    setState(
        () => _nota = context.read<NoteProvider>().byId(_nota.id) ?? _nota);
  }

  Future<void> _collega() async {
    final eventi = widget.eventi;
    final todos = widget.todos;
    if (eventi == null || todos == null) return;
    await showLinkPicker(
      context,
      noteId: _nota.id,
      eventi: eventi,
      todos: todos,
    );
  }

  Future<void> _condividi() async {
    final titolo = _title.text.trim();
    final corpo = _contenuto
        .split('\n')
        .where((line) => !isAttachmentLine(line))
        .map(stripNoteFormat)
        .join('\n')
        .trim();
    if (titolo.isEmpty && corpo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La nota non contiene testo da condividere')),
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        subject: titolo.isEmpty ? 'Nota' : titolo,
        text: [titolo, corpo].where((parte) => parte.isNotEmpty).join('\n\n'),
      ),
    );
  }

  void _setImporting(bool importing) => setState(() => _importing = importing);

  Future<void> _importShared() async {
    final store = context.read<NoteAttachmentStore?>();
    if (store == null || _importing) return;
    setState(() => _importing = true);
    try {
      await _salvaCondivisi(store);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _elimina() async {
    final conferma = await confirmDelete(context, 'la nota');
    if (!conferma || !mounted) return;
    _autosave?.cancel();
    await context.read<NoteProvider>().deleteNote(_nota.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _azione(String valore) async {
    if (_importing) return;
    switch (valore) {
      case 'pin':
        await _togglePin();
      case 'anteprima':
        await _cambiaAnteprima();
      case 'collega':
        await _collega();
      case 'condividi':
        await _condividi();
      case 'elimina':
        await _elimina();
    }
  }

  @override
  Widget build(BuildContext context) => _buildEditor(context);
}
