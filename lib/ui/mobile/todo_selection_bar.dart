import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/todos/domain/todo.dart';
import '../../features/todos/todo_provider.dart';
import '../../features/todos/todo_selection.dart';
import '../../theme/design_tokens.dart';
import '../shared/feedback.dart';
import '../shared/undo.dart';
import 'pickers.dart';

/// La barra della **selezione multipla**: quanti sono scelti, e cosa farne.
///
/// Le quattro azioni scrivono **una volta sola** per tutte le righe
/// (`TodoProvider.scriviMolti`): spuntare venti todo e' una modifica, non venti.
/// Ognuna ha il suo annulla, e l'annulla e' lo **stesso scrittura-in-blocco** con
/// lo stato di prima: una strada sola, non due.
///
/// Nota sul `messenger`: si prende **prima** di chiudere la selezione. Chiudendola
/// la barra sparisce, e il suo `context` non vale piu': l'avviso con «Annulla»
/// deve sopravvivere alla barra che l'ha chiesto.
class TodoSelectionBar extends StatelessWidget {
  const TodoSelectionBar({super.key, required this.visibili});

  /// Gli id che si stanno vedendo: «seleziona tutti» prende **questi**, non tutti
  /// i todo che esistono (chi ha filtrato non si aspetta altro).
  final List<String> visibili;

  @override
  Widget build(BuildContext context) {
    final selezione = context.watch<SelezioneDeiTodo>();
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('chiudi-selezione'),
              tooltip: 'Chiudi la selezione',
              icon: Icon(Icons.close, color: scheme.onPrimaryContainer),
              onPressed: selezione.chiudi,
            ),
            Flexible(
              child: Text(
                '${selezione.quanti} selezionati',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ),
            _azione(
              context,
              key: 'seleziona-tutti',
              tooltip: 'Seleziona tutti',
              icon: Icons.select_all,
              onPressed: () {
                tickFeedback();
                selezione.tutti(visibili);
              },
            ),
            _azione(
              context,
              key: 'spunta-selezione',
              tooltip: 'Segna come fatti',
              icon: Icons.check,
              onPressed: () => _spunta(context),
            ),
            _azione(
              context,
              key: 'sposta-selezione',
              tooltip: 'Sposta la data',
              icon: Icons.event,
              onPressed: () => _sposta(context),
            ),
            _azione(
              context,
              key: 'categoria-selezione',
              tooltip: 'Cambia categoria',
              icon: Icons.label_outline,
              onPressed: () => _categoria(context),
            ),
            _azione(
              context,
              key: 'elimina-selezione',
              tooltip: 'Elimina',
              icon: Icons.delete_outline,
              onPressed: () => _elimina(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _azione(
    BuildContext context, {
    required String key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      key: ValueKey(key),
      tooltip: tooltip,
      // Compatti per forza: col font di sistema ingrandito sei pulsanti e una
      // scritta non entrano in una riga, e «2 selezionati» andava a capo
      // (verificato sul telefono).
      visualDensity: VisualDensity.compact,
      iconSize: 22,
      icon: Icon(icon, color: scheme.onPrimaryContainer),
      onPressed: onPressed,
    );
  }

  /// I todo scelti, presi dalla lista del provider: le azioni lavorano su quelli,
  /// non su un numero.
  List<Todo> _scelti(BuildContext context) {
    final ids = context.read<SelezioneDeiTodo>().ids;
    return [
      for (final todo in context.read<TodoProvider>().todos)
        if (ids.contains(todo.id)) todo,
    ];
  }

  /// Chiude la selezione e mostra l'annulla. Il messenger arriva da fuori perche'
  /// dopo [chiudi] questa barra non c'e' piu', e l'`annulla` lo costruisce chi
  /// chiama: spuntare/spostare/cambiare **rimette lo stato di prima**, cancellare
  /// invece deve **rimettere le righe** (`rimetti: true`), che dal database erano
  /// sparite.
  void _avvisa(
    ScaffoldMessengerState messenger,
    SelezioneDeiTodo selezione,
    String messaggio,
    VoidCallback annulla,
  ) {
    selezione.chiudi();
    showUndoSnackBarOn(messenger, message: messaggio, onUndo: annulla);
  }

  /// L'annulla delle azioni che **modificano**: rimette com'erano.
  void _ripristina(TodoProvider provider, List<Todo> scelti) =>
      provider.scriviMolti([for (final todo in scelti) (todo, todo)]);

  String _contati(int quanti, String singolo, String plurale) =>
      quanti == 1 ? singolo : '$quanti $plurale';

  void _spunta(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final selezione = context.read<SelezioneDeiTodo>();
    final provider = context.read<TodoProvider>();
    final scelti = _scelti(context);
    if (scelti.isEmpty) return;

    provider.scriviMolti([
      for (final todo in scelti) (todo, todo.copyWith(completed: true)),
    ]);
    _avvisa(
        messenger,
        selezione,
        _contati(scelti.length, 'To do fatto', 'To do fatti'),
        () => _ripristina(provider, scelti));
  }

  Future<void> _sposta(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final selezione = context.read<SelezioneDeiTodo>();
    final provider = context.read<TodoProvider>();
    final scelti = _scelti(context);

    final quando = await pickDate(context, initial: DateTime.now());
    if (quando == null || scelti.isEmpty) return;

    final giorno = DateTime(quando.year, quando.month, quando.day);
    provider.scriviMolti([
      for (final todo in scelti) (todo, todo.copyWith(dueDate: giorno)),
    ]);
    _avvisa(
        messenger,
        selezione,
        _contati(scelti.length, 'Data spostata', 'date spostate'),
        () => _ripristina(provider, scelti));
  }

  Future<void> _categoria(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final selezione = context.read<SelezioneDeiTodo>();
    final provider = context.read<TodoProvider>();
    final scelti = _scelti(context);

    final scelta = await pickCategory(context);
    if (scelta == null || scelti.isEmpty) return;

    provider.scriviMolti([
      for (final todo in scelti) (todo, todo.copyWith(categoryIds: scelta)),
    ]);
    _avvisa(
        messenger,
        selezione,
        _contati(scelti.length, 'Categoria cambiata', 'categorie cambiate'),
        () => _ripristina(provider, scelti));
  }

  void _elimina(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final selezione = context.read<SelezioneDeiTodo>();
    final provider = context.read<TodoProvider>();
    final scelti = _scelti(context);
    if (scelti.isEmpty) return;

    provider.scriviMolti([for (final todo in scelti) (todo, null)]);
    _avvisa(
      messenger,
      selezione,
      _contati(scelti.length, 'To do eliminato', 'To do eliminati'),
      // Le righe erano state **tolte** dal database: l'annulla le rimette
      // (`rimetti: true`), con la versione +2 come nell'eliminazione singola.
      () => provider.scriviMolti(
        [for (final todo in scelti) (todo, todo)],
        rimetti: true,
      ),
    );
  }
}
