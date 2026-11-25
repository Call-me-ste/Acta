import 'package:flutter/material.dart';
import 'motion.dart';

/// Chiede conferma prima di eliminare qualcosa.
///
/// Era scritta due volte identica (eventi e todo): la domanda è la stessa, il
/// testo che cambia è solo l'oggetto. Qui sta una volta, e i form la chiamano.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final confirmed = await showActaDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Eliminare $what?'),
      content: const Text("L'operazione non si può annullare."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Elimina'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
