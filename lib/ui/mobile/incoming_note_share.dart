import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/events/event_provider.dart';
import '../../features/notes/domain/note.dart';
import '../../features/notes/note_attachment_store.dart';
import '../../features/notes/note_provider.dart';
import '../../features/todos/todo_provider.dart';
import '../../theme/design_tokens.dart';
import 'note_editor_page.dart';
import 'note_attachment_picker.dart';

class IncomingNoteShare extends StatefulWidget {
  const IncomingNoteShare({super.key, required this.child});

  final Widget child;

  @override
  State<IncomingNoteShare> createState() => _IncomingNoteShareState();
}

class _IncomingNoteShareState extends State<IncomingNoteShare> {
  static const _channel = MethodChannel('planner/shared_files');
  bool _active = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.read<NoteAttachmentStore?>() != null) {
          _active = true;
          _channel.setMethodCallHandler((call) async {
            if (call.method == 'ready') await _receive();
          });
          _receive();
        }
      });
    }
  }

  @override
  void dispose() {
    if (_active) _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _receive() async {
    if (_busy) return;
    _busy = true;
    try {
      while (mounted) {
        final batch = await _channel.invokeMapMethod<Object?, Object?>('take');
        final raw = batch?['files'] as List? ?? const [];
        final skipped = skippedAttachments(batch);
        if (raw.isEmpty && skipped.isEmpty) return;
        if (!mounted) return;
        if (skipped.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${skipped.length} file esclusi. ${skipped.toSet().join(" ")}'),
          ));
        }
        if (raw.isEmpty) continue;
        final files = [
          for (final item in raw)
            (
              path: item['path'] as String,
              name: item['name'] as String,
              kind: NoteAttachmentKind.values.byName(item['kind'] as String),
            ),
        ];
        try {
          if (!mounted) return;
          final notes = context.read<NoteProvider>();
          final choice = await showActaSheet<String>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _ShareDestination(notes: notes.notes),
          );
          if (choice == null || !mounted) continue;
          final selected =
              choice.isEmpty ? await notes.addNote() : notes.byId(choice);
          if (selected == null || !mounted) continue;
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => NoteEditorPage(
              note: selected,
              eventi: context.read<EventProvider?>(),
              todos: context.read<TodoProvider?>(),
              sharedAttachments: files,
            ),
          ));
        } finally {
          for (final item in files) {
            try {
              await File(item.path).delete();
            } on FileSystemException {
              // The system may already have cleared a staged share.
            }
          }
        }
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('File condiviso non disponibile. Riprova.')),
        );
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ShareDestination extends StatefulWidget {
  const _ShareDestination({required this.notes});

  final List<Note> notes;

  @override
  State<_ShareDestination> createState() => _ShareDestinationState();
}

class _ShareDestinationState extends State<_ShareDestination> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final notes = [
      for (final note in widget.notes)
        if (note.title.toLowerCase().contains(_query)) note,
    ];
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: TextField(
                onChanged: (value) =>
                    setState(() => _query = value.toLowerCase().trim()),
                decoration: const InputDecoration(labelText: 'Cerca una nota'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Nuova nota'),
              onTap: () => Navigator.pop(context, ''),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return ListTile(
                    title:
                        Text(note.title.isEmpty ? 'Senza titolo' : note.title),
                    onTap: () => Navigator.pop(context, note.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
