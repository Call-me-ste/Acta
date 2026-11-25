import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/database_service.dart';
import '../../features/events/domain/event.dart';
import '../../features/events/event_provider.dart';
import '../../features/notes/domain/note.dart';
import '../../features/search/item_search_controller.dart';
import '../../features/todos/domain/todo.dart';
import '../../features/todos/todo_provider.dart';
import '../../theme/design_tokens.dart';
import 'item_detail_sheet.dart';
import 'note_editor_page.dart';

class ItemSearchButton extends StatelessWidget {
  const ItemSearchButton({super.key, this.onOpenDay});

  final ValueChanged<DateTime>? onOpenDay;

  @override
  Widget build(BuildContext context) {
    final database = context.read<DatabaseService?>();
    if (database == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: IconButton.filledTonal(
        tooltip: 'Cerca in Acta',
        icon: const Icon(Icons.search),
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => ItemSearchController(database),
              child: _ItemSearchPage(onOpenDay: onOpenDay),
            ),
          ));
        },
      ),
    );
  }
}

class _ItemSearchPage extends StatelessWidget {
  const _ItemSearchPage({this.onOpenDay});

  final ValueChanged<DateTime>? onOpenDay;

  @override
  Widget build(BuildContext context) {
    final search = context.watch<ItemSearchController>();
    final results = search.results;
    return Scaffold(
      appBar: AppBar(title: const Text('Cerca in Acta')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: TextField(
                autofocus: true,
                onChanged: search.setQuery,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => search.refresh(),
                decoration: const InputDecoration(
                  hintText: 'Eventi, To do e note',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            if (search.hasMore)
              const Text('Affina la ricerca per restringere i risultati'),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(switch ((
                      search.isEmptyQuery,
                      search.loading,
                      search.failed
                    )) {
                      (true, _, _) => 'Cerca per titolo, luogo o contenuto.',
                      (_, true, _) => 'Ricerca in corso…',
                      (_, _, true) => 'Ricerca non riuscita. Riprova.',
                      _ => 'Nessun risultato',
                    }))
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: results.length,
                      itemBuilder: (context, index) =>
                          _tile(context, search, results[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
      BuildContext context, ItemSearchController search, SearchHit hit) {
    final date = hit.date;
    final label = hit.kind.label;
    return ListTile(
      leading: Icon(switch (hit.kind) {
        SearchKind.event => Icons.event_outlined,
        SearchKind.todo => Icons.task_alt_outlined,
        SearchKind.note => Icons.note_outlined,
      }),
      title: Text(hit.title.isEmpty ? 'Nota senza titolo' : hit.title),
      subtitle: Text(date == null
          ? label
          : '$label · ${MaterialLocalizations.of(context).formatMediumDate(date)}'),
      onTap: () => _open(context, search, hit),
      trailing: onOpenDay == null || date == null
          ? null
          : IconButton(
              tooltip: 'Vai al giorno',
              onPressed: () {
                Navigator.of(context).pop();
                onOpenDay!(date);
              },
              icon: const Icon(Icons.calendar_today_outlined),
            ),
    );
  }

  Future<void> _open(
      BuildContext context, ItemSearchController search, SearchHit hit) async {
    FocusScope.of(context).unfocus();
    switch (search.read(hit)) {
      case final Event event:
        await showItemDetail(context, event: event, day: event.start);
      case final Todo todo:
        await showItemDetail(context, todo: todo, day: todo.dueDate);
      case final Note note:
        final events = context.read<EventProvider>();
        final todos = context.read<TodoProvider>();
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              NoteEditorPage(note: note, eventi: events, todos: todos),
        ));
    }
    if (context.mounted) await search.refresh();
  }
}
