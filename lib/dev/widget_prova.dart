import 'package:flutter/material.dart';

import '../features/widgets/home_widget_bridge.dart';
import '../features/widgets/widget_contract.dart';

/// Gli attrezzi da banco dei widget: **esistono solo nella build di test**
/// (`lib/core/dev_flags.dart`), come i dati di prova.
///
/// Servono a una cosa sola: provare sul telefono il cambio di **giornata** senza
/// aspettare la mezzanotte. Il pacchetto porta otto giorni e il renderer sceglie
/// la chiave del giorno che serve: questa riga gli dice di credere che oggi sia un
/// altro giorno — cioè esattamente quello che succederà alle 00:05, quando
/// l'allarme ridisegna il widget.
///
/// Nella build ufficiale la sezione non c'è e la chiave non la scrive nessuno: il
/// Kotlin la ignora quando non è una data, quindi non può restare «accesa» per
/// sbaglio.
class WidgetProva extends StatelessWidget {
  const WidgetProva({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const ValueKey('widget-prova-domani'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.update),
          title: const Text('Widget: come se fosse domani'),
          subtitle: const Text(
            'Ridisegna i widget sulla giornata di domani, come al cambio di '
            'giorno',
          ),
          onTap: () => _sposta(context, giorni: 1),
        ),
        ListTile(
          key: const ValueKey('widget-prova-oggi'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restore),
          title: const Text('Widget: torna a oggi'),
          onTap: () => _sposta(context, giorni: 0),
        ),
      ],
    );
  }

  Future<void> _sposta(BuildContext context, {required int giorni}) async {
    final adesso = DateTime.now();
    final giorno = DateTime(adesso.year, adesso.month, adesso.day + giorni);

    await const HomeWidgetBridge().fintaOggi(giorni == 0 ? null : giorno);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            giorni == 0
                ? 'I widget mostrano di nuovo oggi'
                : 'I widget mostrano $dataIso(giorno)',
          ),
        ),
      );
  }
}
