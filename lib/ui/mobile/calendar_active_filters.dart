import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/filters/filtro_condiviso.dart';
import '../../features/filters/filtro_condiviso_controller.dart';
import '../../theme/design_tokens.dart';

class CalendarActiveFilters extends StatelessWidget {
  const CalendarActiveFilters({super.key, required this.filter});

  final FiltroCondiviso filter;

  @override
  Widget build(BuildContext context) {
    final count = filter.categorieScelte.length;
    if (count == 0 && filter.cosa == CosaMostrare.entrambi) {
      return const SizedBox.shrink();
    }
    final detail = [
      if (filter.cosa != CosaMostrare.entrambi)
        cosaMostrareLabels[filter.cosa]!,
      if (count == 1) '1 categoria',
      if (count > 1) '$count categorie',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Row(
        children: [
          Expanded(child: Text('Filtri attivi · $detail')),
          TextButton(
            onPressed:
                context.read<FiltroCondivisoController>().clearCalendarFilters,
            child: const Text('Azzera'),
          ),
        ],
      ),
    );
  }
}
