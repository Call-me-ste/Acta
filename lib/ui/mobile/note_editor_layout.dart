part of 'note_editor_page.dart';

extension _NoteEditorLayout on _NoteEditorPageState {
  void _allegatoMessaggio(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _allega(NoteAttachmentStore store) async {
    if (_importing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final scelta = await scegliAllegato(context);
    if (scelta == null || !mounted) return;
    _setImporting(true);
    try {
      final pdf = scelta == 'pdf' || scelta == 'scan';
      final selection = await selezionaAllegati(context, scelta);
      final errors = [...selection.skipped];
      final inserted = <String>[];
      for (final file in selection.files) {
        try {
          if (!mounted) continue;
          final attachment = await store.importFile(
            File(file.path),
            noteId: _nota.id,
            name: file.name,
            kind: pdf ? NoteAttachmentKind.pdf : NoteAttachmentKind.photo,
            pdfThumbnail: pdf ? await creaAnteprimaPdf(File(file.path)) : null,
          );
          inserted.add(attachment.id);
        } catch (error) {
          errors.add(attachmentErrorMessage(error));
        } finally {
          if (Platform.isAndroid) {
            final staged = File(file.path);
            if (await staged.exists()) await staged.delete();
          }
        }
      }
      if (!mounted) return;
      _editorKey.currentState?.insertAttachments(inserted);
      if (mounted && _dirty) await _salvaSenzaChiudere();
      if (mounted && errors.isNotEmpty) {
        _allegatoMessaggio(attachmentBatchMessage(inserted.length, errors));
      }
    } catch (error) {
      if (mounted) {
        _allegatoMessaggio(attachmentErrorMessage(error));
      }
    } finally {
      if (mounted) _setImporting(false);
    }
  }

  Future<void> _salvaCondivisi(NoteAttachmentStore store) async {
    final ids = <String>[];
    final errors = <String>[];
    for (final attachment in widget.sharedAttachments) {
      final file = File(attachment.path);
      try {
        final saved = await store.importFile(
          file,
          noteId: _nota.id,
          name: attachment.name,
          kind: attachment.kind,
          pdfThumbnail: attachment.kind == NoteAttachmentKind.pdf
              ? await creaAnteprimaPdf(file)
              : null,
        );
        ids.add(saved.id);
      } catch (error) {
        errors.add(attachmentErrorMessage(error));
      }
    }
    if (!mounted) return;
    _editorKey.currentState?.insertAttachments(ids);
    if (_dirty) await _salvaSenzaChiudere();
    if (mounted && errors.isNotEmpty) {
      _allegatoMessaggio(attachmentBatchMessage(ids.length, errors));
    }
  }

  Widget _buildEditor(BuildContext context) {
    final attachments = context.read<NoteAttachmentStore?>();
    return PopScope(
      canPop: false,
      // Uscire da una nota **salva**: il dubbio «ho perso quello che ho
      // scritto?» è il difetto che un editor con autosave deve togliere.
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _importing) return;
        _autosave?.cancel();
        if (_dirty && !await _salvaSenzaChiudere()) return;
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: NoteEditorAppBar(
          salvato: _salvato && !_dirty,
          saveFailed: _saveFailed,
          canUndo: _canUndo,
          canRedo: _canRedo,
          onUndo: () => _editorKey.currentState?.undo(),
          onRedo: () => _editorKey.currentState?.redo(),
          pinned: _nota.pinned,
          anteprima: _anteprima,
          collegaDisponibile: widget.eventi != null && widget.todos != null,
          onSelected: _azione,
          onBack: () {
            if (!_importing) Navigator.maybePop(context);
          },
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.s,
              AppSpacing.page,
              AppSpacing.s,
            ),
            child: Column(
              children: [
                Expanded(
                  child: NoteEditorBody(
                    title: _title,
                    content: _contenuto,
                    editorKey: _editorKey,
                    folders: context.read<NoteProvider>().folders,
                    folderId: _nota.folderId,
                    updatedAt: _nota.updatedAt,
                    anteprima: _anteprima,
                    onFolder: _scegliCartella,
                    onContentChanged: _onContenuto,
                    onToggle: _spunta,
                    onHistory: _storicoCambiato,
                    onListIndentChanged: (indent) => _listIndent.value = indent,
                    attachmentBuilder: (id, remove) => NoteAttachmentTile(
                      key: ValueKey(id),
                      store: attachments,
                      noteId: _nota.id,
                      id: id,
                      onRemove: remove,
                      onRename: _markDirty,
                    ),
                  ),
                ),
                NoteEditorFooter(
                  testo: _testo,
                  titolo: _title,
                  contenuto: _testoContenuto,
                  noteId: _nota.id,
                  eventi: widget.eventi,
                  todos: widget.todos,
                  anteprima: _anteprima,
                  onAnteprima: _cambiaAnteprima,
                  onChecklist: () => _converti(NoteBlockKind.checkbox),
                  onBullet: () => _converti(NoteBlockKind.bullet),
                  onNumbered: () => _converti(NoteBlockKind.numbered),
                  onHeading: () => _converti(NoteBlockKind.heading),
                  onIndent: () => _editorKey.currentState?.indent(1),
                  onOutdent: () => _editorKey.currentState?.indent(-1),
                  listIndent: _listIndent,
                  onFormat: (value) => _editorKey.currentState?.formatText(
                    ink: value == 'highlight' || value == 'default'
                        ? null
                        : NoteInk.values.byName(value),
                    highlight: value == 'highlight',
                  ),
                  onAttach:
                      attachments == null ? null : () => _allega(attachments),
                ),
                if (_importing) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
