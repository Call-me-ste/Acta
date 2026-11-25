import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/events/event_provider.dart';
import '../../features/notes/note_provider.dart';
import '../../features/todos/todo_provider.dart';
class NoteLinkPicker extends StatelessWidget {
  const NoteLinkPicker({
    super.key,
    required this.noteId,
    required this.eventi,
    required this.todos,
  });

  final String noteId;
  final EventProvider eventi;
  final TodoProvider todos;

  Future<void> _collega(
    BuildContext context,
    String tipo,
    String id,
  ) async {
    await context.read<NoteProvider>().linkNote(
          noteId: noteId,
          entityType: tipo,
          entityId: id,
        );
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final eventiVisibili = eventi.events.take(50).toList();
    final todoVisibili = [
      for (final todo in todos.todos)
        if (!todo.completed) todo,
    ].take(50).toList();
    final noteVisibili = [
      for (final nota in context.read<NoteProvider>().notes)
        if (nota.id != noteId) nota,
    ].take(50).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Collega a…'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Eventi'),
              Tab(text: 'To do'),
              Tab(text: 'Note'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Lista(
              vuoto: 'Nessun evento',
              lunghezza: eventiVisibili.length,
              builder: (context, indice) {
                final evento = eventiVisibili[indice];
                return ListTile(
                  key: ValueKey('link-event-${evento.id}'),
                  leading: const Icon(Icons.event_outlined),
                  title: Text(evento.title),
                  onTap: () => _collega(context, 'event', evento.id),
                );
              },
            ),
            _Lista(
              vuoto: 'Nessun To do aperto',
              lunghezza: todoVisibili.length,
              builder: (context, indice) {
                final todo = todoVisibili[indice];
                return ListTile(
                  key: ValueKey('link-todo-${todo.id}'),
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(todo.title),
                  onTap: () => _collega(context, 'todo', todo.id),
                );
              },
            ),
            _Lista(
              vuoto: 'Nessun\'altra nota',
              lunghezza: noteVisibili.length,
              builder: (context, indice) {
                final nota = noteVisibili[indice];
                return ListTile(
                  key: ValueKey('link-note-${nota.id}'),
                  leading: const Icon(Icons.sticky_note_2_outlined),
                  title: Text(
                    nota.title.trim().isEmpty ? 'Senza titolo' : nota.title,
                  ),
                  onTap: () => _collega(context, 'note', nota.id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({
    required this.vuoto,
    required this.lunghezza,
    required this.builder,
  });

  final String vuoto;
  final int lunghezza;
  final Widget Function(BuildContext, int) builder;

  @override
  Widget build(BuildContext context) {
    if (lunghezza == 0) {
      return Center(child: Text(vuoto));
    }
    return ListView.builder(
      itemCount: lunghezza,
      itemBuilder: builder,
    );
  }
}


