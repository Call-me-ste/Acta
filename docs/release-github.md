# Release Android

1. Incrementare il numero di build in `pubspec.yaml` e `lib/core/app_version.dart`. Aggiornare le voci di **Cosa c’è di nuovo** in `lib/ui/mobile/updates_page.dart`.
2. Eseguire `flutter analyze` e `flutter test`. Compilare l’APK ufficiale da una copia pulita usando il profilo locale di firma e OAuth.

   ```sh
   flutter build apk --release --flavor production --target-platform android-arm64 --dart-define=PLANNER_DRIVE_OAUTH=true
   ```

3. Verificare con `aapt dump badging` il pacchetto `com.callmeste.planner` e il numero di build. Confrontare la firma con la release precedente usando `apksigner verify --print-certs`. Aprire l’APK su un dispositivo di prova per verificare che mostri la build e le novità attese. In caso di librerie Gradle obsolete, rigenerare gli intermedi di `build/app` e ripetere il controllo sull’APK.
4. Calcolare lo SHA-256 del file da distribuire. Pubblicare una release ordinaria con note di rilascio, APK firmato e checksum. Per `1.3.0+55`, usare il tag `v1.3.0-build.55` e chiamare l’asset `acta-v1.3.0-build.55-android-arm64.apk`. Il controllo in-app richiede una release pubblica del canale stabile e il nome esatto dell’asset.
5. Verificare i link pubblici e provare il flusso di aggiornamento da una build ufficiale precedente.

Una build di sviluppo o firmata con un altro certificato richiede un’installazione separata. Per questo si può usare il flavor `qa`, con il proprio pacchetto e un archivio separato.
