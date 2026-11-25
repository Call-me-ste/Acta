import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/events/domain/event_occurrence.dart';
import '../../features/widgets/widget_bridge.dart';
import 'form_sheet.dart';

/// Il foglio che sceglie l'evento del countdown per **quella** istanza.
Future<void> mostraSelettoreCountdown(
  BuildContext context, {
  required int widgetId,
  required WidgetBridge ponte,
  required List<EventOccurrence> occorrenze,
}) {
  return showFormSheet(
    context,
    (contestoFoglio) => SelettoreCountdown(
      widgetId: widgetId,
      ponte: ponte,
      occorrenze: occorrenze,
    ),
  );
}

class SelettoreCountdown extends StatefulWidget {
  const SelettoreCountdown({
    super.key,
    required this.widgetId,
    required this.ponte,
    required this.occorrenze,
  });

  final int widgetId;
  final WidgetBridge ponte;
  final List<EventOccurrence> occorrenze;

  @override
  State<SelettoreCountdown> createState() => _SelettoreCountdownStato();
}

class _SelettoreCountdownStato extends State<SelettoreCountdown> {
  final _nome = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _salva(EventOccurrence occorrenza) async {
    final nome = _nome.text.trim();
    await widget.ponte.salvaCountdown(
      widgetId: widget.widgetId,
      eventoId: occorrenza.event.id,
      titolo: nome.isEmpty ? occorrenza.title : nome,
      data: occorrenza.date,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occorrenze = widget.occorrenze;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Countdown', style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _nome,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            decoration: const InputDecoration(
              labelText: 'Nome sul widget (facoltativo)',
            ),
          ),
        ),
        Expanded(
          child: occorrenze.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nessun evento nei prossimi mesi.'),
                )
              : ListView.builder(
                  itemCount: occorrenze.length,
                  itemBuilder: (contesto, indice) {
                    final occorrenza = occorrenze[indice];
                    return ListTile(
                      title: Text(occorrenza.title),
                      subtitle: Text(etichettaCountdown(occorrenza.date)),
                      onTap: () => unawaited(_salva(occorrenza)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// «24 nov», con l'anno solo quando serve.
String etichettaCountdown(DateTime giorno) {
  const mesi = [
    'gen',
    'feb',
    'mar',
    'apr',
    'mag',
    'giu',
    'lug',
    'ago',
    'set',
    'ott',
    'nov',
    'dic',
  ];
  final base = '${giorno.day} ${mesi[giorno.month - 1]}';
  return giorno.year == DateTime.now().year ? base : '$base ${giorno.year}';
}
