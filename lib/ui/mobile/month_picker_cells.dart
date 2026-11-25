import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Le celle dei due fogli di scelta (mese e settimana), con la **gerarchia delle
/// evidenze** che dicono le linee guida:
///
/// - **scelto** (il mese o la settimana in cui sei): riempimento pieno col colore
///   d'accento e testo invertito — e' l'informazione principale, e il contrasto
///   deve reggere (4,5:1 sul riempimento);
/// - **oggi**: **solo un bordo** di 1 dp nello stesso accento, senza riempimento.
///   Non e' un'informazione principale: e' un punto di riferimento. Material 3 fa
///   esattamente cosi' nel date picker (giorno scelto: `primary` pieno; oggi:
///   contenitore trasparente, testo `primary`, bordo 1 dp).
/// - **oggi e scelto insieme**: vince lo scelto, il bordo di oggi non si disegna
///   (regola di Material 3). Due evidenze della stessa forza non si distinguono.
///
/// Il bordo e non un velo di colore: il colore da solo non basta (chi non lo
/// distingue vede due celle uguali), e un bordo e' una *forma*.
class StatoCella {
  const StatoCella({required this.scelto, required this.oggi});

  final bool scelto;
  final bool oggi;
}

/// Una voce della striscia degli anni.
class AnnoPill extends StatelessWidget {
  const AnnoPill({
    super.key,
    required this.anno,
    required this.scelto,
    required this.oggi,
    required this.onTap,
  });

  final int anno;
  final bool scelto;

  /// Vero per l'anno corrente: trattato come «oggi», quindi in secondo piano.
  final bool oggi;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final evidenziato = StatoCella(scelto: scelto, oggi: oggi);

    return Center(
      child: Material(
        color: evidenziato.scelto ? scheme.primary : Colors.transparent,
        shape: AppRadius.pill,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(999),
              // Oggi (e non scelto): solo il bordo.
              border: !evidenziato.scelto && evidenziato.oggi
                  ? Border.all(color: scheme.primary, width: 1)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            child: Text(
              '$anno',
              // Una riga, sempre: la voce e' larga quanto serve (cresce col testo).
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: (evidenziato.scelto
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.bodyLarge)
                  ?.copyWith(
                color: evidenziato.scelto
                    ? scheme.onPrimary
                    : evidenziato.oggi
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                fontWeight:
                    evidenziato.scelto ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una cella della griglia dei mesi.
class MeseCell extends StatelessWidget {
  const MeseCell({
    super.key,
    required this.etichetta,
    required this.scelto,
    required this.oggi,
    required this.onTap,
  });

  final String etichetta;
  final bool scelto;
  final bool oggi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scelto ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.button),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            // Il mese di oggi: bordo, non riempimento. Se e' anche quello scelto,
            // il bordo non c'e' (vince lo scelto, come dice Material 3).
            border: !scelto && oggi
                ? Border.all(color: scheme.primary, width: 1)
                : null,
          ),
          child: Center(
            child: Text(
              etichetta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scelto
                    ? scheme.onPrimary
                    : oggi
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                fontWeight: scelto ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una riga dell'elenco delle settimane: l'intervallo dei giorni, e sotto il mese
/// quando la settimana lo scavalca.
///
/// La settimana **scelta** e' quella in cui stai: pieno d'accento. La settimana
/// che contiene oggi ha il bordo, come le altre celle.
class WeekRow extends StatelessWidget {
  const WeekRow({
    super.key,
    required this.monday,
    required this.scelto,
    required this.oggi,
    required this.onTap,
  });

  final DateTime monday;
  final bool scelto;
  final bool oggi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final domenica = DateTime(monday.year, monday.month, monday.day + 6);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Material(
        color: scelto ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.button),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.touchTarget,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: !scelto && oggi
                  ? Border.all(color: scheme.primary, width: 1)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _intervallo(monday, domenica),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scelto ? scheme.onPrimary : scheme.onSurface,
                      fontWeight: scelto ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (oggi)
                  Text(
                    'oggi',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scelto ? scheme.onPrimary : scheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// «1 – 7 set», oppure con due mesi quando la settimana li scavalca.
  static String _intervallo(DateTime lunedi, DateTime domenica) {
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
    if (lunedi.month == domenica.month) {
      return '${lunedi.day} – ${domenica.day} ${mesi[lunedi.month - 1]}';
    }
    return '${lunedi.day} ${mesi[lunedi.month - 1]} – '
        '${domenica.day} ${mesi[domenica.month - 1]}';
  }
}
