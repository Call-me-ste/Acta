import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Registro dei fotogrammi, per le misure in **`--profile`**.
///
/// Si accende con `--dart-define=frameLog=true`; spento non costa niente, perché
/// la costante è `const` e il ramo viene tolto in compilazione. Le righe escono
/// nel log di `flutter run`, o in `adb logcat` per una build installata.
///
/// Perché esiste: i numeri di prestazione vanno presi **sul dispositivo**, e in
/// debug non valgono niente (sull'emulatore il primo fotogramma passa da 99 ms in
/// profile a 2691 ms in debug). Questo evita di inventare una misura o di
/// scrivere ogni volta codice temporaneo — e serve a chi verifica dopo di noi.
const bool frameLogEnabled = bool.fromEnvironment('frameLog');

/// Il tempo per fotogramma, in microsecondi, diviso per thread: `build` è il
/// lavoro Dart (dove cadono letture e calcoli), `raster` è la GPU (dove cadono
/// opacità, clip e ombre).
///
/// Le righe escono con `debugPrint` e **non** con `dart:developer.log`: quello,
/// senza un client collegato al VM service, non arriva nel logcat — e una build
/// installata sul telefono non ha nessun client collegato.
void startFrameLog() {
  if (!frameLogEnabled) return;

  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    for (final timing in timings) {
      debugPrint(
        'FOTOGRAMMA build=${timing.buildDuration.inMicroseconds}us '
        'raster=${timing.rasterDuration.inMicroseconds}us '
        'totale=${timing.totalSpan.inMicroseconds}us',
      );
    }
  });

  debugPrint('registro fotogrammi attivo (--dart-define=frameLog=true)');
}
