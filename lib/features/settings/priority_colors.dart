import '../../theme/color_resolver.dart';

/// I colori delle quattro priorita', nell'ordine in cui il codice le numera:
/// 0 Bassa, 1 Media, 2 Alta, 3 Urgente.
///
/// Sono **scelti a mano** e non presi dal tema: il tema cambia con la palette,
/// mentre "urgente e' rosso" deve restare vero anche se la palette del momento
/// ha l'accento verde. Chi vuole cambiarli li cambia da Impostazioni >
/// Organizzazione > Priorita', e la scelta resta su questo device (come il tema:
/// telefono e PC possono volerne di diversi).
const List<String> defaultPriorityColors = [
  '#4CAF50', // Bassa: verde
  '#FFD600', // Media: giallo
  '#FF9800', // Alta: arancione
  '#F44336', // Urgente: rosso
];

/// Codifica i quattro colori nell'unica stringa che sta in `app_settings`.
String encodePriorityColors(List<String> colors) => colors.join(',');

/// L'inverso, tollerante: un colore rotto o assente ricade sul suo valore di
/// base, perche' una priorita' senza colore sarebbe una priorita' invisibile.
/// Il numero di colori e' sempre quello dei livelli, mai di piu' ne' di meno.
List<String> parsePriorityColors(String? raw) {
  final parti = (raw ?? '').split(',');

  return [
    for (var i = 0; i < defaultPriorityColors.length; i++)
      if (i < parti.length && ColorResolver.hexToColor(parti[i]) != null)
        parti[i].trim()
      else
        defaultPriorityColors[i],
  ];
}
