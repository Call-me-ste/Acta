import 'package:flutter/material.dart';

/// Stato vuoto condiviso: stessa forma in tutte le sezioni.
///
/// Prima ne esistevano quattro copie identiche, una per pagina: il tipo di
/// duplicazione che in v2 ha portato a file da migliaia di righe.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;

  /// L'azione che fa uscire dallo stato vuoto («Nuova nota»). Il vuoto dice
  /// cosa fare, non solo che non c'è niente.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    // Centra quando lo spazio basta, scorre quando non basta (in mese, la
    // lista ha a volte 99 px): un solo pixel di troppo non deve traboccare.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            // La **larghezza** va imposta: uno scroll verticale dà vincoli
            // sciolti in orizzontale, quindi la colonna si restringerebbe al
            // testo e resterebbe appoggiata a sinistra (è il difetto visto a
            // occhio in Todo e Agenda). Dentro uno `Scaffold` la larghezza è
            // già stretta, ed è per questo che lì sembrava a posto.
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 34,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: color,
                      ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 16),
                  action!,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
