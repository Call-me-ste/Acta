import 'package:flutter/material.dart';

import '../../features/calendar_import/calendar_import_service.dart';
import '../../features/calendar_import/domain/device_calendar_gateway.dart';
import '../../theme/design_tokens.dart';

/// Il primo schermo dell'import quando il permesso non c'è (o il dispositivo
/// non è supportato). Sta fuori dalla pagina per il tetto delle 300 righe.
class ImportAccessNotice extends StatelessWidget {
  const ImportAccessNotice({
    super.key,
    required this.access,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final CalendarAccess? access;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (access == CalendarAccess.unavailable) {
      return const ImportMessage(
        'L’import dal calendario è disponibile su Android e iOS.',
        errore: false,
      );
    }
    if (access == CalendarAccess.restricted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ImportMessage(
            'L’accesso al calendario è limitato dal sistema. Puoi sbloccarlo '
            'dalle impostazioni del telefono.',
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Apri le impostazioni'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ImportMessage(
          'Per importare gli eventi serve il permesso di leggere il calendario '
          'del telefono. Il Planner non modifica il calendario esterno.',
        ),
        const SizedBox(height: AppSpacing.s),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Consenti accesso al calendario'),
        ),
        TextButton(
          onPressed: onOpenSettings,
          child: const Text('Apri le impostazioni'),
        ),
      ],
    );
  }
}

class ImportMessage extends StatelessWidget {
  const ImportMessage(this.testo, {super.key, this.errore = true});

  final String testo;
  final bool errore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: errore ? scheme.errorContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(
        testo,
        style: TextStyle(
          color: errore ? scheme.onErrorContainer : scheme.onSurface,
        ),
      ),
    );
  }
}

class ImportSuccess extends StatelessWidget {
  const ImportSuccess({super.key, required this.result});

  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(
        result.imported == 1
            ? '1 evento importato.'
            : '${result.imported} eventi importati.',
        style: TextStyle(color: scheme.onPrimaryContainer),
      ),
    );
  }
}

class ImportPreview extends StatelessWidget {
  const ImportPreview({
    super.key,
    required this.plan,
    required this.importing,
    required this.onImport,
  });

  final ImportPlan plan;
  final bool importing;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pronti = plan.importable;
    final duplicati = plan.duplicates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          pronti == 1 ? '1 evento da importare' : '$pronti eventi da importare',
          style: theme.textTheme.titleMedium,
        ),
        if (duplicati > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            duplicati == 1
                ? '1 evento già presente, saltato'
                : '$duplicati eventi già presenti, saltati',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.m),
        FilledButton.icon(
          onPressed: pronti == 0 || importing ? null : onImport,
          icon: importing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: Text(
            importing
                ? 'Importazione…'
                : pronti == 0
                    ? 'Niente da importare'
                    : 'Importa $pronti ${pronti == 1 ? 'evento' : 'eventi'}',
          ),
        ),
      ],
    );
  }
}
