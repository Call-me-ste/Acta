import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/formatters.dart';

import '../../theme/design_tokens.dart';
import '../shared/date_math.dart';
import '../shared/feedback.dart';

/// Le intestazioni dei giorni della settimana: sigla + numero, il selezionato
/// nel cerchio pieno, oggi col numero colorato.
///
/// La larghezza arriva da fuori (è la larghezza totale delle 7 colonne, pannata
/// in sync con la griglia): ogni cella è larga esattamente `width / giorni`.
class WeekDayHeaders extends StatelessWidget {
  const WeekDayHeaders({
    super.key,
    required this.days,
    required this.width,
    required this.selectedDay,
    this.now,
    this.onDaySelected,
    this.onOpenDay,
    this.animate = true,
  });

  final List<DateTime> days;
  final double width;
  final DateTime selectedDay;
  final DateTime? now;
  final ValueChanged<DateTime>? onDaySelected;

  /// Tocco prolungato: si apre il giorno (stessa scorciatoia della vista mese).
  final ValueChanged<DateTime>? onOpenDay;

  /// Animazioni accese: la tinta del giorno scelto si accende e si spegne invece
  /// di saltare (stessa regola delle celle del mese).
  final bool animate;

  /// Il cerchio del numero cresce col testo: a 2.0 un numero da 28 sp non sta
  /// in 30 px. Non cresce oltre il necessario.
  static double circleSize(BuildContext context) {
    final stile = Theme.of(context).textTheme.labelLarge!;
    final line = MediaQuery.textScalerOf(context).scale(stile.fontSize ?? 14) *
        (stile.height ?? 1.2);
    return math.max(30, line + 2);
  }

  /// L'altezza della fascia: sigla + distacco + cerchio + padding verticale.
  static double height(BuildContext context) {
    final stile = Theme.of(context).textTheme.labelSmall!;
    final line = MediaQuery.textScalerOf(context).scale(stile.fontSize ?? 11) *
        (stile.height ?? 1.2);
    return line +
        AppSpacing.xs +
        circleSize(context) +
        AppSpacing.xs * 2 +
        AppSpacing.xs / 2;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cerchio = circleSize(context);
    final tinta = AppMotion.effective(
      enabled: animate,
      wanted: AppMotion.normal,
    );

    return Row(
      children: [
        for (final day in days)
          SizedBox(
            width: width / days.length,
            child: InkWell(
              onTap: onDaySelected == null ? null : () => onDaySelected!(day),
              // Tocco prolungato: si apre quel giorno nella vista giorno, con lo
              // stesso colpetto di vibrazione che usa il mese.
              onLongPress: onOpenDay == null
                  ? null
                  : () {
                      tickFeedback();
                      onOpenDay!(day);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    Text(
                      giornoBreve(day.weekday),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Il giorno selezionato: cerchio pieno, come nella vista
                    // mese, e come là la tinta si accende e si spegne invece di
                    // saltare. Anche qui il cerchio c'è sempre (trasparente
                    // quando non serve), altrimenti il colore non si può
                    // interpolare.
                    AnimatedContainer(
                      duration: tinta,
                      curve: AppMotion.curve,
                      width: cerchio,
                      height: cerchio,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isSelected(day)
                            ? scheme.primary
                            : _isToday(day)
                                ? scheme.primary.withValues(alpha: 0.15)
                                : const Color(0x00000000),
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedDefaultTextStyle(
                        duration: tinta,
                        curve: AppMotion.curve,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: _isSelected(day)
                                      ? scheme.onPrimary
                                      : _isToday(day)
                                          ? scheme.primary
                                          : scheme.onSurface,
                                  fontWeight: _isSelected(day) || _isToday(day)
                                      ? FontWeight.w600
                                      : null,
                                ) ??
                            const TextStyle(),
                        child: Text('${day.day}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _isSelected(DateTime day) => dateOnly(day) == dateOnly(selectedDay);

  bool _isToday(DateTime day) {
    final now = this.now;
    return now != null && dateOnly(day) == dateOnly(now);
  }
}
