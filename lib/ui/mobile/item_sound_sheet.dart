import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../theme/design_tokens.dart';

/// Il nome del suono configurato nelle impostazioni: quello che la riga del form
/// mostra come «predefinito», invece di un «Come impostazioni» che non dice
/// niente.
String soundName(String suono) => switch (suono) {
      'sveglia' => 'Sveglia',
      'suoneria' => 'Suoneria',
      'nessuno' => 'Silenzioso',
      _ => 'Sistema',
    };

/// La riga del form per il suono di **questo** elemento.
String soundSummary(bool? sound, String defaultSound) {
  if (sound == null) return soundName(defaultSound);
  return sound ? 'Suona' : 'Silenzioso';
}

/// Il risultato del foglio suono: `sound` null = predefinito.
class SoundChoice {
  const SoundChoice(this.sound);

  final bool? sound;
}

/// Il foglio del suono: tre stati, con il default scritto per esteso.
Future<SoundChoice?> scegliSuono(
  BuildContext context, {
  required bool? sound,
  required String defaultSound,
}) {
  return showActaSheet<SoundChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      Widget voce({
        required bool? valore,
        required String titolo,
        String? nota,
      }) {
        final scelta = sound == valore;
        return ListTile(
          title: Text(titolo),
          subtitle: nota == null ? null : Text(nota),
          trailing: scelta
              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
              : null,
          onTap: () => Navigator.pop(ctx, SoundChoice(valore)),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  0,
                  AppSpacing.l,
                  AppSpacing.s,
                ),
                child: Text('Suono', style: theme.textTheme.titleMedium),
              ),
              voce(
                valore: null,
                titolo: 'Predefinito',
                nota: soundName(defaultSound),
              ),
              voce(valore: true, titolo: 'Suona'),
              voce(valore: false, titolo: 'Silenzioso'),
            ],
          ),
        ),
      );
    },
  );
}
