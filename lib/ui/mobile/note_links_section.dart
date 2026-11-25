import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/events/event_provider.dart';
import '../../features/notes/domain/note_link.dart';
import '../../features/notes/note_link_suggestions.dart';
import '../../features/notes/note_provider.dart';
import '../../features/todos/todo_provider.dart';
import '../../theme/design_tokens.dart';
import 'note_link_picker.dart';

/// I collegamenti di una nota, con il picker «Collega a…» e **un solo**
/// suggerimento discreto quando nota e elemento condividono parole.
///
/// Il widget è facoltativo: senza `EventProvider`/`TodoProvider` (per esempio
/// nei test del solo editor) non compare.
class NoteLinksSection extends StatefulWidget {
  const NoteLinksSection({
    super.key,
    required this.noteId,
    this.eventi,
    this.todos,
  });

  final String noteId;
  final EventProvider? eventi;
  final TodoProvider? todos;

  @override
  State<NoteLinksSection> createState() => _NoteLinksSectionState();
}

class _NoteLinksSectionState extends State<NoteLinksSection> {
  String? _scartato;

  bool get _disponibile => widget.eventi != null && widget.todos != null;

  String _titolo(NoteLink link, NoteProvider provider) {
    if (link.entityType == 'event') {
      for (final evento in widget.eventi?.events ?? const []) {
        if (evento.id == link.entityId) return evento.title;
      }
    } else if (link.entityType == 'todo') {
      for (final todo in widget.todos?.todos ?? const []) {
        if (todo.id == link.entityId) return todo.title;
      }
    } else if (link.entityType == 'note') {
      final altra = link.noteId == widget.noteId ? link.entityId : link.noteId;
      return provider.byId(altra)?.title ?? 'Nota';
    }
    return 'Elemento non disponibile';
  }

  LinkSuggestion? _suggerimento(NoteProvider provider) {
    if (!_disponibile) return null;
    final nota = provider.byId(widget.noteId);
    if (nota == null || (nota.title.isEmpty && nota.content.isEmpty)) {
      return null;
    }
    final candidati = [
      for (final evento in widget.eventi!.events)
        LinkCandidate(
          entityType: 'event',
          id: evento.id,
          title: evento.title,
        ),
      for (final todo in widget.todos!.todos)
        if (!todo.completed)
          LinkCandidate(
            entityType: 'todo',
            id: todo.id,
            title: todo.title,
          ),
    ];
    final scelta = miglioreCollegamento(
      testo: '${nota.title}\n${nota.content}',
      candidati: candidati,
    );
    if (scelta == null || scelta.key == _scartato) return null;
    return scelta;
  }

  @override
  Widget build(BuildContext context) {
    if (!_disponibile) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final provider = context.watch<NoteProvider>();
    final uscenti = provider.linksOfNote(widget.noteId);
    final entranti = [
      for (final link in provider.linksOfEntity('note', widget.noteId))
        if (!uscenti
            .any((u) => u.entityType == 'note' && u.entityId == link.noteId))
          link,
    ];
    final links = [...uscenti, ...entranti];
    final suggerimento = links.isEmpty ? _suggerimento(provider) : null;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (links.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text('Collegamenti', style: theme.textTheme.labelMedium),
            ),
          if (suggerimento != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: InputChip(
                key: ValueKey('suggerimento-${suggerimento.key}'),
                avatar: const Icon(
                  Icons.auto_awesome,
                  size: AppSpacing.iconSmall,
                ),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    'Collega a ${suggerimento.candidate.title}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onPressed: () async {
                  await provider.linkNote(
                    noteId: widget.noteId,
                    entityType: suggerimento.candidate.entityType,
                    entityId: suggerimento.candidate.id,
                  );
                  if (mounted) setState(() => _scartato = suggerimento.key);
                },
                onDeleted: () => setState(() => _scartato = suggerimento.key),
                deleteIcon: const Icon(
                  Icons.close,
                  size: AppSpacing.iconSmall,
                ),
              ),
            ),
          if (links.isNotEmpty)
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final link in links)
                  InputChip(
                    key: ValueKey('link-${link.id}'),
                    avatar: Icon(
                      switch (link.entityType) {
                        'event' => Icons.event_outlined,
                        'todo' => Icons.check_circle_outline,
                        _ => Icons.sticky_note_2_outlined,
                      },
                      size: AppSpacing.iconSmall,
                    ),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        _titolo(link, provider),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onDeleted: () =>
                        context.read<NoteProvider>().unlinkNote(link.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Apre il selettore dei collegamenti: la stessa strada per il menu `⋮` e per
/// il suggerimento in fondo alla nota.
Future<void> showLinkPicker(
  BuildContext context, {
  required String noteId,
  required EventProvider eventi,
  required TodoProvider todos,
}) {
  return showActaSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.72,
      child: NoteLinkPicker(noteId: noteId, eventi: eventi, todos: todos),
    ),
  );
}
