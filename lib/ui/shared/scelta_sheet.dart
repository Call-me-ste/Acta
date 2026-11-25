import 'package:flutter/material.dart';

import 'motion.dart';
import '../../theme/design_tokens.dart';

/// Un foglio che chiede **una scelta fra poche voci**, ognuna con la sua nota.
///
/// Sta in `ui/shared/` perché lo usano due cose che non c'entrano niente fra
/// loro — le ore silenziose degli avvisi e le tre modalità dei todo in calendario
/// — e perché la forma è sempre la stessa: un titolo, tre o quattro righe, la
/// scelta che torna al chiamante. Il foglio **non** scrive niente: chi chiama sa
/// dove mettere la risposta.
Future<String?> mostraSceltaAzione(
  BuildContext context, {
  required String titolo,
  required List<({String valore, String etichetta, String nota})> voci,
}) {
  return showActaSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: Text(titolo, style: Theme.of(context).textTheme.titleSmall),
          ),
          for (final voce in voci)
            ListTile(
              key: ValueKey('azione-${voce.valore}'),
              title: Text(voce.etichetta),
              subtitle: Text(voce.nota),
              onTap: () => Navigator.pop(context, voce.valore),
            ),
        ],
      ),
    ),
  );
}
