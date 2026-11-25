import 'package:flutter/material.dart';

/// Un avviso con «Annulla», cinque secondi per rimediare.
///
/// Non è un vezzo: è l'unica rete contro il tocco sbagliato che non ferma
/// nessuno. Un dialogo di conferma ferma **tutti** i casi (anche quelli in cui
/// l'utente sa cosa sta facendo); l'undo lascia fare e rimediare.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  showUndoSnackBarOn(
    ScaffoldMessenger.of(context),
    message: message,
    onUndo: onUndo,
  );
}

/// Come [showUndoSnackBar], ma su un messenger già preso: serve quando chi
/// chiama sta per sparire (il form si chiude subito dopo la cancellazione) e il
/// suo `context` non varrà più.
void showUndoSnackBarOn(
  ScaffoldMessengerState messenger, {
  required String message,
  required VoidCallback onUndo,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        // Tre secondi: il tempo di leggere e toccare «Annulla», e poi via. Un
        // avviso che resta è un avviso che copre l'interfaccia.
        duration: const Duration(seconds: 3),
        // **Esplicito**: in questa versione di Flutter una SnackBar *con azione*
        // è persistente per default (`persist = persist ?? action != null` in
        // `snack_bar.dart`), quindi non se ne andava mai — il difetto segnalato.
        persist: false,
        action: SnackBarAction(label: 'Annulla', onPressed: onUndo),
      ),
    );
}
