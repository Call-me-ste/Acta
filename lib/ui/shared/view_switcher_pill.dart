import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Una voce del selettore a pillola.
class ViewSwitcherEntry<T> {
  const ViewSwitcherEntry({required this.value, required this.label});

  final T value;
  final String label;
}

/// Le etichette restano al loro posto mentre si sposta la pastiglia.
class ViewSwitcherPill<T> extends StatelessWidget {
  const ViewSwitcherPill({
    super.key,
    required this.entries,
    required this.value,
    required this.onChanged,
    this.animate = true,
  });

  final List<ViewSwitcherEntry<T>> entries;
  final T value;
  final ValueChanged<T> onChanged;

  /// Acceso dalle preferenze (o dal "riduci animazioni" di sistema): spento, il
  /// movimento è zero — vedi [AppMotion.effective].
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final index = entries.indexWhere((entry) => entry.value == value);
    final selectedIndex = index < 0 ? 0 : index;

    // Il bordo della pillola è fuori dal bersaglio. A testo grande cresce lo
    // spazio necessario alle etichette.
    final height = AppSpacing.labelBarHeight(context) + 2 * AppSpacing.xs;
    final radius = AppRadius.pillRadius(height);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.s,
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            height: height,
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: radius,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / entries.length;
                final seconds = AppMotion.effective(
                  enabled: animate,
                  wanted: AppMotion.controlSelection,
                );

                return Stack(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SizedBox(
                        width: itemWidth,
                        height: double.infinity,
                        child: AnimatedSlide(
                          duration: seconds,
                          curve: AppMotion.controlCurve,
                          offset: Offset(
                            Directionality.of(context) == TextDirection.rtl
                                ? -selectedIndex.toDouble()
                                : selectedIndex.toDouble(),
                            0,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: radius,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final entry in entries)
                          Expanded(
                            child: _Segment<T>(
                              entry: entry,
                              selected: entry.value == value,
                              animate: animate,
                              onTap: () => onChanged(entry.value),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.entry,
    required this.selected,
    required this.animate,
    required this.onTap,
  });

  final ViewSwitcherEntry<T> entry;
  final bool selected;
  final bool animate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelLarge?.copyWith(
      color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
    );

    // La semantica dice "bottone, selezionato": un lettore di schermo deve
    // poter capire dove sei, non solo leggere le tre parole.
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillRadius(AppSpacing.touchTarget),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.effective(
              enabled: animate,
              wanted: AppMotion.fast,
            ),
            style: style ?? const TextStyle(),
            child: Text(entry.label),
          ),
        ),
      ),
    );
  }
}
