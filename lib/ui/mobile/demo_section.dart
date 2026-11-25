import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/database_service.dart';
import '../../dev/demo_data.dart';
import '../../dev/stress_data.dart';
import '../../dev/widget_prova.dart';
import '../../features/events/event_provider.dart';
import '../../features/todos/todo_provider.dart';

/// I comandi dei **dati di prova**: caricarli per vedere l'app con un'agenda
/// piena, rimuoverli per tornare ai propri.
///
/// Sezione dichiaratamente di sviluppo: si toglie cancellando questo file,
/// `dev/demo_data.dart` e la riga che li mette nelle impostazioni.
class DemoSection extends StatelessWidget {
  const DemoSection({super.key});

  Future<void> _carica(BuildContext context) async {
    final db = context.read<DatabaseService>();
    final quanti = await DemoData.load(db);
    if (!context.mounted) return;

    // I provider tengono una copia in memoria: dopo una scrittura diretta
    // (fuori dall'outbox, come questa) vanno rilette, altrimenti le viste
    // mostrano ancora i dati di prima.
    context.read<TodoProvider>().reload();
    context.read<EventProvider>().reload();
    _dici(context, 'Caricati $quanti elementi di prova');
  }

  void _rimuovi(BuildContext context) {
    final tolti = DemoData.remove(context.read<DatabaseService>());
    context.read<TodoProvider>().reload();
    context.read<EventProvider>().reload();
    _dici(context, 'Rimossi $tolti elementi di prova');
  }

  Future<void> _caricaStress(BuildContext context) async {
    final db = context.read<DatabaseService>();
    final quanti = await StressData.load(db);
    if (!context.mounted) return;

    context.read<TodoProvider>().reload();
    context.read<EventProvider>().reload();
    _dici(context, 'Caricati $quanti elementi di stress');
  }

  void _rimuoviStress(BuildContext context) {
    final tolti = StressData.remove(context.read<DatabaseService>());
    context.read<TodoProvider>().reload();
    context.read<EventProvider>().reload();
    _dici(context, 'Rimossi $tolti elementi di stress');
  }

  void _dici(BuildContext context, String messaggio) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(messaggio)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: const ValueKey('carica-demo'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.science_outlined),
          title: const Text('Carica dati di prova'),
          subtitle: const Text(
            '${DemoData.todos} To do e ${DemoData.events} eventi, '
            'come un\'agenda piena',
          ),
          onTap: () => _carica(context),
        ),
        ListTile(
          key: const ValueKey('rimuovi-demo'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline),
          title: const Text('Rimuovi dati di prova'),
          subtitle: const Text('Toglie solo quello che ha caricato lui'),
          onTap: () => _rimuovi(context),
        ),
        ListTile(
          key: const ValueKey('carica-stress'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.speed_outlined),
          title: const Text('Carica dati di stress'),
          subtitle: const Text(
            '${StressData.eventi} eventi in un giorno e ${StressData.todo} To do: '
            'il caso cattivo, per misurare',
          ),
          onTap: () => _caricaStress(context),
        ),
        ListTile(
          key: const ValueKey('rimuovi-stress'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_sweep_outlined),
          title: const Text('Rimuovi dati di stress'),
          subtitle: const Text('Toglie solo il carico di prova'),
          onTap: () => _rimuoviStress(context),
        ),
        // Gli attrezzi da banco dei widget: si vedono solo qui, e solo nella
        // build di test (come tutto il resto di questa sezione).
        const WidgetProva(),
      ],
    );
  }
}
