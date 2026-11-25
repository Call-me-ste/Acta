import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/events/event_provider.dart';
import '../../features/notes/domain/note.dart';
import '../../features/notes/domain/note_folder.dart';
import '../../features/notes/domain/note_order.dart';
import '../../features/notes/note_provider.dart';
import '../../features/notes/note_selection.dart';
import '../../features/notes/note_tags.dart';
import '../../features/todos/todo_provider.dart';
import '../../theme/design_tokens.dart';
import '../shared/empty_state.dart';
import '../shared/page_header.dart';
import '../shared/tab_active.dart';
import 'note_create_sheet.dart';
import 'note_editor_page.dart';
import 'note_folder_actions.dart';
import 'note_folders_bar.dart';
import 'note_folders_sheet.dart';
import 'note_row.dart';
import 'note_search_field.dart';
import 'note_selection_bar.dart';
import 'note_tags_bar.dart';
import 'note_tags_sheet.dart';

part 'note_list_memo.dart';

/// La scheda Note: testata, ricerca, cartelle, elenco a righe.
///
/// Un solo «+» apre il foglio Crea (nota o cartella); la barra mostra le
/// cartelle fissate e il comando per l'elenco completo.
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _ricerca = TextEditingController();
  final _memo = _NoteListMemo();
  String _filtro = 'tutte';
  String? _tag;
  NoteOrdine _ordine = NoteOrdine.aggiornate;

  @override
  void dispose() {
    _ricerca.dispose();
    super.dispose();
  }

  Future<void> _apri(Note note) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorPage(
          note: note,
          eventi: context.read<EventProvider>(),
          todos: context.read<TodoProvider>(),
        ),
      ),
    );
  }

  Future<void> _nuova() async {
    final cartella = _filtro == 'tutte' || _filtro == 'senza' ? null : _filtro;
    final note = await context.read<NoteProvider>().addNote(folderId: cartella);
    if (!mounted) return;
    await _apri(note);
  }

  Future<void> _creaCartella() async {
    final cartella = await creaCartella(context, context.read<NoteProvider>());
    if (cartella != null && mounted) {
      setState(() => _filtro = cartella.id);
    }
  }

  Future<void> _mostraCrea() async {
    final scelta = await mostraCreaSheet(context);
    if (!mounted || scelta == null) return;
    if (scelta == 'nota') {
      await _nuova();
    } else {
      await _creaCartella();
    }
  }

  Future<void> _apriCartelle() async {
    final scelta = await mostraCartelleSheet(context, selected: _filtro);
    if (!mounted || scelta == null) return;
    if (scelta == '__nuova__') {
      await _creaCartella();
      return;
    }
    setState(() => _filtro = scelta);
  }

  NoteFolder? _cartellaDi(Note note, List<NoteFolder> folders) {
    for (final folder in folders) {
      if (folder.id == note.folderId) return folder;
    }
    return null;
  }

  Future<void> _apriTag() async {
    final scelta = await mostraTagSheet(
      context,
      counts: _memo.tagCountsByName,
      selected: _tag,
    );
    if (!mounted || scelta == null) return;
    setState(() => _tag = scelta == '__tutti__' ? null : scelta);
  }

  String _messaggioVuoto(String query) {
    if (query.isNotEmpty) return 'Nessun risultato';
    if (_tag != null) return 'Nessuna nota con #$_tag';
    if (_filtro == 'senza') return 'Nessuna nota senza cartella';
    if (_filtro != 'tutte') return 'Cartella vuota';
    return 'Nessuna nota';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NoteProvider>();
    return AscoltatoriSeAttivo(
      notifiers: [provider],
      builder: (context) => _buildNotes(context, provider),
    );
  }

  Widget _buildNotes(BuildContext context, NoteProvider provider) {
    final selezione = context.watch<SelezioneDelleNote>();
    final query = _ricerca.text.trim().toLowerCase();
    _memo.update(
        provider.notes, _ordine, (folder: _filtro, tag: _tag, query: query));
    final note = _memo.visible;
    final pinnedHeader = note.firstOrNull?.pinned ?? false;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 0, elevation: 0),
      body: Column(
        children: [
          if (selezione.attiva)
            NoteSelectionBar(visibili: [for (final n in note) n.id])
          else ...[
            PageHeader(
              title: 'Note',
              actions: [
                PopupMenuButton<NoteOrdine>(
                  popUpAnimationStyle: menuMotion(context),
                  key: const ValueKey('ordina-note'),
                  tooltip: 'Ordina note',
                  icon: const Icon(Icons.sort),
                  initialValue: _ordine,
                  onSelected: (valore) => setState(() => _ordine = valore),
                  itemBuilder: (context) => [
                    for (final voce in NoteOrdine.values)
                      CheckedPopupMenuItem(
                        key: ValueKey('ordine-${voce.name}'),
                        value: voce,
                        checked: _ordine == voce,
                        child: Text(voce.label),
                      ),
                  ],
                ),
                IconButton(
                  key: const ValueKey('crea'),
                  tooltip: 'Crea',
                  onPressed: _mostraCrea,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            NoteSearchField(
              controller: _ricerca,
              onChanged: (_) => setState(() {}),
            ),
            NoteFoldersBar(
              folders: provider.folders,
              selected: _filtro,
              onSelected: (valore) => setState(() => _filtro = valore),
              onLongPress: (folder) =>
                  gestisciCartella(context, provider, folder),
              onAll: _apriCartelle,
            ),
            const SizedBox(height: AppSpacing.s),
            NoteTagsBar(
              tags: _memo.tags,
              selected: _tag,
              onSelected: (tag) => setState(() => _tag = tag),
              onAll: _apriTag,
            ),
          ],
          Expanded(
            child: note.isEmpty
                ? EmptyState(
                    icon: Icons.edit_note_outlined,
                    message: _messaggioVuoto(query),
                    action: query.isEmpty && _filtro != 'senza'
                        ? TextButton.icon(
                            onPressed: _nuova,
                            icon: const Icon(Icons.add),
                            label: const Text('Nuova nota'),
                          )
                        : null,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xs,
                      bottom: AppSpacing.xl,
                    ),
                    itemCount: note.length + (pinnedHeader ? 1 : 0),
                    itemBuilder: (context, indice) {
                      if (pinnedHeader && indice == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.page,
                            AppSpacing.m,
                            AppSpacing.page,
                            AppSpacing.xs,
                          ),
                          child: Text(
                            'Fissate',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 0.6,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        );
                      }
                      final n = note[pinnedHeader ? indice - 1 : indice];
                      return NoteRow(
                        note: n,
                        folder: _cartellaDi(n, provider.folders),
                        selectionMode: selezione.attiva,
                        selected: selezione.contiene(n.id),
                        onTap: () => selezione.attiva
                            ? selezione.inverti(n.id)
                            : _apri(n),
                        onLongPress: () => selezione.apri(n.id),
                        onPin: () =>
                            context.read<NoteProvider>().togglePinned(n),
                        onDelete: () =>
                            context.read<NoteProvider>().deleteNote(n.id),
                        onToggleSelected: () => selezione.inverti(n.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
