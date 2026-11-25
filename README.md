# Acta

Agenda, note e To do per Android. Puoi usare Acta offline e collegare facoltativamente Google Drive per sincronizzare un archivio cifrato tra i tuoi dispositivi.

- Organizza eventi, ricorrenze, scadenze e promemoria.
- Scrivi note e allega immagini, PDF o scansioni di documenti.
- Crea copie locali ed esporta un backup cifrato `.planner`.

## Beta Android

[Scarica Acta da GitHub Releases](https://github.com/Call-me-ste/Acta/releases/latest)

L’APK ufficiale richiede Android 7.0 o successivo e un dispositivo ARM64. Per aggiornare un’installazione esistente, installa l’APK sopra la versione già presente. Il recupero dei dati sincronizzati su un nuovo dispositivo richiede lo stesso account Google e la chiave di recupero di Acta.

[Informativa sulla privacy](https://polar-reef-515315-e1.web.app/privacy.html) · [Segnala un problema](https://github.com/Call-me-ste/Acta/issues)

## Sviluppo locale

Servono Flutter, l’SDK Android e un dispositivo o emulatore Android. La beta è stata compilata con Flutter 3.44.2. Esegui dalla radice del progetto:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

La build di sviluppo funziona offline. L’integrazione Drive richiede una configurazione OAuth Android per il pacchetto e il certificato di firma della build, oltre al flag `--dart-define=PLANNER_DRIVE_OAUTH=true`.

Per installare una seconda app con dati separati e comandi di prova, usa `flutter run --flavor qa`. Android la mostra come **Acta Test**. La sincronizzazione Drive è disattivata in questa variante.

## Aggiornare Acta da GitHub

All’apertura, Acta per Android controlla le release pubbliche del progetto. In **Impostazioni → Aggiornamenti** puoi avviare il controllo e leggere le novità della versione installata, anche offline. Quando appare **Aggiornamento disponibile**, tocca la scheda per creare e verificare una copia locale prima di aprire la release ufficiale. Scarica l’APK e installalo sopra Acta con il programma di installazione Android. La copia è consultabile in **Impostazioni → Copie di sicurezza**.

Le istruzioni per il mantenimento delle [release Android](docs/release-github.md) descrivono il formato dei tag e i controlli sulla build firmata.

## Licenza

Il codice originale di Acta è distribuito con licenza [MIT](LICENSE). Il carattere Inter mantiene la propria licenza [SIL Open Font License 1.1](assets/fonts/OFL.txt).
