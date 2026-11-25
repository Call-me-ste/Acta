import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/settings/app_settings_controller.dart';
import '../../features/settings/priority_colors.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import '../shared/color_field.dart';
import '../shared/color_name.dart';
import '../shared/priority_style.dart';

/// "Priorita'": i quattro colori dei livelli.
///
/// Sono una preferenza del **device** (come il tema) e non una proprieta' della
/// palette: cambiando il colore dell'app, "urgente e' rosso" deve restare vero.
class PriorityPage extends StatelessWidget {
  const PriorityPage({super.key});

  Future<void> _scegli(BuildContext context, int livello) async {
    final settings = context.read<AppSettingsController>();
    final scelto = await showColorDialog(
      context,
      initialHex: settings.priorityColorOf(livello),
      title: priorityLabel(livello),
    );
    if (scelto == null) return;
    settings.setPriorityColor(livello, scelto);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<AppSettingsController>();
    final sonoDiBase =
        settings.priorityColors.join() == defaultPriorityColors.join();

    return Scaffold(
      appBar: AppBar(title: const Text('Priorita\'')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          Text(
            'I colori delle priorita\': si vedono sulla scheda del To do e '
            'nelle viste del calendario.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.s),
          // Dal piu' urgente al piu' basso: e' l'ordine in cui si guardano.
          for (final livello in [3, 2, 1, 0])
            ListTile(
              key: ValueKey('priorita-$livello'),
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: priorityColorFrom(settings.priorityColors, livello),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  priorityIcon(livello),
                  size: 18,
                  color: ColorResolver.onColor(
                    priorityColorFrom(settings.priorityColors, livello),
                  ),
                ),
              ),
              title: Text(priorityLabel(livello)),
              // Il nome del colore, non il codice: chi sceglie "rosso" non ha
              // perche' leggere #F44336.
              subtitle: Text(colorNameOfHex(settings.priorityColorOf(livello))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _scegli(context, livello),
            ),
          const SizedBox(height: AppSpacing.s),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('ripristina-priorita'),
              // Spento quando sono gia' quelli di base: un tasto che non cambia
              // niente e' un tasto che si tocca per sbaglio.
              onPressed: sonoDiBase ? null : settings.resetPriorityColors,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Ripristina i colori di base'),
            ),
          ),
        ],
      ),
    );
  }
}
