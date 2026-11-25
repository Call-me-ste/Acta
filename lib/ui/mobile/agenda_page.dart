import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/calendar/agenda_days.dart';
import '../../features/events/event_provider.dart';
import '../../features/filters/filtro_condiviso.dart';
import '../../features/filters/filtro_condiviso_controller.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../features/todos/todo_provider.dart';
import '../../theme/design_tokens.dart';
import '../shared/empty_state.dart';
import '../shared/filtro_attivo.dart';
import '../shared/tab_active.dart';
import 'agenda_list.dart';
import 'agenda_filter_bar.dart';

/// L'agenda: **un gruppo per giorno**, dal più vicino in avanti.
///
/// Prima era un elenco piatto — una riga per occorrenza, trenta giorni fissi —
/// e non si capiva dove finisce un giorno e comincia il successivo: i giorni
/// vuoti non fanno un'intestazione, e chi ha qualcosa si legge a colpo d'occhio
/// (numero grande a sinistra, la linea che scende, e a destra i box).
///
/// Cosa si vede lo dicono il **filtro condiviso** (categorie, cosa mostrare,
/// orizzonte) e la modalità dei todo (`TodoInCalendario`): in «nascosta» i todo
/// non entrano qui, perché il loro posto è la scheda Todo — la stessa regola
/// del calendario.
class AgendaPage extends StatelessWidget {
  const AgendaPage({super.key, this.oggi});

  /// Oggi. `null` nell'app (si legge l'orologio), iniettato dai test: una
  /// schermata che dipende dal giorno in cui gira il test non si può provare.
  final DateTime? oggi;

  @override
  Widget build(BuildContext context) {
    // Il filtro lo monta `main()`; una pagina montata da sola (i test della sola
    // agenda) puo' non averlo, e allora non c'e' niente da ascoltare: e' la
    // stessa scelta di `filtroAttivo`, che vale «nessun vincolo».
    final controllerDelFiltro = context.read<FiltroCondivisoController?>();

    return Scaffold(
      // Intestazione vuota: il nome della sezione e' gia' nella barra di
      // navigazione in basso. Resta alta zero, cosi' il contenuto non finisce
      // sotto la status bar e non si perde spazio per un titolo ripetuto.
      appBar: AppBar(toolbarHeight: 0, elevation: 0),
      body: AscoltatoriSeAttivo(
        // Il filtro e le preferenze **fra i notifier**: chi guarda l'agenda si
        // iscrive a tutto (i dati e le due lenti), e chi sta dietro la barra in
        // basso non si iscrive a niente. Il perche' sta in `tab_active.dart`.
        notifiers: [
          context.read<EventProvider>(),
          context.read<TodoProvider>(),
          context.read<AppSettingsController>(),
          if (controllerDelFiltro != null) controllerDelFiltro,
        ],
        builder: (context) {
          final filtro = filtroAttuale(context);
          final modo = context.read<AppSettingsController>().todoInCalendario;

          final filtroEffettivo = modo == TodoInCalendario.nascosta
              ? filtro.copyWith(cosa: CosaMostrare.eventi)
              : filtro;
          final giorni = giorniDellAgenda(
            from: oggi ?? DateTime.now(),
            giorni: filtro.giorni,
            events: context.read<EventProvider>(),
            todos: context.read<TodoProvider>(),
            // In «nascosta» i todo non entrano in agenda: la loro lente li toglie
            // qui, dove si legge la preferenza, e non dentro i gruppi.
            filtro: filtroEffettivo,
          );

          return Column(
            children: [
              // La barra c'è **sempre** (anche senza niente da mostrare: è da lì
              // che si toglie il filtro che ha svuotato l'agenda) — ma solo se
              // c'è un filtro da comandare.
              if (controllerDelFiltro != null) const AgendaFilterBar(),
              if (giorni.isNotEmpty) _Conteggio(giorni: giorni),
              Expanded(
                child: giorni.isEmpty
                    ? EmptyState(
                        icon: Icons.view_agenda_outlined,
                        message: filtro.isEmpty
                            ? switch (filtroEffettivo.cosa) {
                                CosaMostrare.eventi => 'Nessun evento prossimo',
                                CosaMostrare.todo =>
                                  'Nessun To do in programma',
                                CosaMostrare.entrambi => 'Niente in programma',
                              }
                            : 'Nessun risultato con questi filtri',
                      )
                    : AgendaList(days: giorni, today: oggi),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Quello che si vede, contato: «12 eventi · 5 todo».
///
/// Sta in cima perché è la risposta alla domanda che si fa guardando un elenco
/// lungo — «quanto c'è?» — e perché è anche la prova che un filtro ha fatto
/// qualcosa.
class _Conteggio extends StatelessWidget {
  const _Conteggio({required this.giorni});

  final List<GiornoDellAgenda> giorni;

  @override
  Widget build(BuildContext context) {
    var eventi = 0;
    var todo = 0;
    for (final giorno in giorni) {
      eventi += giorno.eventi;
      todo += giorno.todos.length;
    }

    final parti = [
      if (eventi > 0) eventi == 1 ? '1 evento' : '$eventi eventi',
      if (todo > 0) '$todo To do',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s,
        AppSpacing.page,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          parti.join(' · '),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
