import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/database_files.dart';
import '../../core/database/database_service.dart';
import '../../features/backup/backup_controller.dart';

/// I due momenti in cui la copia ha bisogno di **sapere cosa fa l'app**:
/// quando si apre e quando si chiude (o va in secondo piano).
///
/// Un widget e non del codice dentro `main.dart` per un motivo pratico: cosi' si
/// puo' provare. Le due cose che fa non si vedono a occhio — una copia che parte
/// dopo il primo fotogramma e un WAL che rientra nel file principale — e sono
/// esattamente le due che, se smettessero di funzionare, non se ne accorgerebbe
/// nessuno fino al giorno in cui servono.
class BackupGuard extends StatefulWidget {
  const BackupGuard({super.key, required this.child});

  final Widget child;

  @override
  State<BackupGuard> createState() => _BackupGuardState();
}

class _BackupGuardState extends State<BackupGuard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // **Dopo** il primo fotogramma: una copia è un `VACUUM INTO` completo, e
    // l'avvio non deve aspettarla. Quando parte, la prima schermata è già
    // disegnata e il database è già aperto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Prima la manutenzione **una volta sola** (accende `auto_vacuum` e
      // restituisce lo spazio: su un database esistente costa un `VACUUM` e non
      // si può fare a ogni avvio), poi la compattazione **se serve** (coda da
      // ripulire o pagine da restituire, non più di una volta a settimana), e
      // infine la copia automatica — che così copia un file già compatto.
      context.read<DatabaseService>().manutenzioneUnaTantum();
      context.read<DatabaseService>().compattaSeServe();
      unawaited(context.read<BackupController>().autoSeDovuta());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // In secondo piano — che su Android vuol dire "posso essere ammazzata in
    // qualsiasi momento" — il WAL rientra nel file principale.
    //
    // Perché conta: l'auto backup di Google copia **i file** quando l'app è
    // ferma, e il `-wal` è escluso dalle regole (copiarlo insieme al database
    // principale significherebbe mischiare due stati). Senza questo checkpoint
    // la copia di Android sarebbe più vecchia dell'ultima modifica.
    if (state != AppLifecycleState.paused) return;
    if (!mounted) return;
    context.read<DatabaseService>().checkpoint();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
