import 'package:flutter/services.dart';

/// Un tocco di vibrazione quando qualcosa cambia stato.
///
/// Importo **leggero**: qui si spunta un todo, non si segnala un errore. Il
/// feedback tattile è metà di quella sensazione "solida" delle interfacce di
/// sistema, e costa una riga. Sui dispositivi senza motore è un no-op.
void tickFeedback() {
  HapticFeedback.lightImpact();
}
