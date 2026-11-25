import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'ui/app_shell.dart';
import 'ui/shared/widget_open.dart';
import 'core/app_version.dart';
import 'core/database/database_service.dart';
import 'core/dev_flags.dart';
import 'core/perf/frame_log.dart';
import 'core/services/auth_service.dart';
import 'core/sync/sync_service.dart';
import 'core/sync/android_drive_auth.dart';
import 'core/sync/drive_sync_gateway.dart';
import 'core/sync/sync_auth.dart';
import 'core/sync/encrypted_sync_gateway.dart';
import 'core/sync/sync_attachment_transport.dart';
import 'core/sync/sync_manifest.dart';
import 'core/sync/unconfigured_sync_auth.dart';
import 'features/backup/backup_controller.dart';
import 'features/backup/domain/backup_file.dart';
import 'features/backup/backup_service.dart';
import 'features/calendar/giorno_richiesto.dart';
import 'features/categories/category_controller.dart';
import 'features/categories/category_seed.dart';
import 'features/events/event_provider.dart';
import 'features/filters/filtro_condiviso_controller.dart';
import 'features/notes/note_provider.dart';
import 'features/notes/note_attachment_store.dart';
import 'features/notes/note_attachment_sync.dart';
import 'features/notes/note_selection.dart';
import 'features/notifications/flutter_local_notifications_sink.dart';
import 'features/notifications/notification_open.dart';
import 'features/notifications/notification_scheduler.dart';
import 'features/notifications/notification_settings_controller.dart';
import 'features/notifications/notification_sink.dart';
import 'features/palette/palette_controller.dart';
import 'features/settings/app_settings_controller.dart';
import 'features/todos/todo_filter_controller.dart';
import 'features/sync/sync_controller.dart';
import 'features/todos/todo_provider.dart';
import 'features/todos/todo_selection.dart';
import 'features/updates/update_controller.dart';
import 'features/widgets/home_widget_bridge.dart';
import 'features/widgets/widget_contract.dart';
import 'ui/shared/backup_guard.dart';
import 'ui/shared/migration_backup_page.dart';
import 'ui/shared/reminder_guard.dart';
import 'ui/shared/widget_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La licenza del font incorporato viaggia con l'app.
  LicenseRegistry.addLicense(() async* {
    final testo = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Inter'], testo);
  });

  // Misura dei fotogrammi: senza `--dart-define=frameLog=true` non fa niente.
  startFrameLog();
  await _startApp();
}

Future<void> _startApp() async {
  // I nomi di giorni e mesi li formatta intl: senza i dati di locale caricati
  // restano in inglese (o intl lancia un errore sul locale it_IT).
  await initializeDateFormatting('it_IT');

  // L'URI di avvio da widget va letto **prima** del primo frame: il guscio
  // decide se mostrare gli scaduti all'apertura, e un tocco su «Agenda» deve
  // portare al giorno scelto, non far comparire un foglio sopra.
  final avvioWidget = await const HomeWidgetBridge().uriDiAvvio();
  final giornoDaWidget = leggiToccaDelWidget(avvioWidget)?.giorno;
  final giornoRichiesto = GiornoRichiesto();
  if (giornoDaWidget != null) giornoRichiesto.chiedi(giornoDaWidget);

  // Initialize database
  //
  // La cartella delle copie si decide **prima** di aprire il database: se questa
  // apertura deve portare lo schema a una versione nuova, la copia va fatta
  // prima di toccarlo — ed e' il gancio qui sotto a farla.
  final database = DatabaseService();
  final copieDiSicurezza = BackupService(
    database,
    cartella: await BackupService.cartellaPredefinita(),
  );
  DateTime? copiaPreAggiornamento;
  try {
    await database.init(
      appVersion: AppVersion.full,
      primaDiAggiornare: (daVersione, daAppVersion) async {
        try {
          final copia = await copieDiSicurezza.snapshot(
            motivo: BackupReason.preAggiornamento,
          );
          copiaPreAggiornamento = copia.createdAt;
          return true;
        } catch (errore) {
          // Il database rinvia eventuali migrazioni finché la copia non riesce.
          debugPrint(
              '[copie] la copia prima dell\'aggiornamento non è riuscita: '
              '$errore');
          return false;
        }
      },
    );
  } on MigrationBackupRequired {
    giornoRichiesto.dispose();
    runApp(const MigrationBackupPage(retry: _startApp));
    return;
  }

  // Palette e preferenze si caricano **prima** di runApp: leggere il tema al
  // primo frame evita il lampo di un tema sbagliato all'avvio. Prima le
  // palette **e il loro allineamento**, poi le preferenze: la migrazione puo'
  // spostare il tema attivo (un colore vecchio, il piu' vicino) e il tema si
  // deve leggere dopo, se no il primo frame usa il valore vecchio.
  final palettes = PaletteController(database)
    ..load()
    ..allineaPresets();
  final settings = AppSettingsController(database.settings)..load();
  final copiaIniziale = copiaPreAggiornamento;
  if (copiaIniziale != null) settings.markBackupDone(copiaIniziale);
  // Le preferenze delle notifiche: sedici chiavi con default espliciti, lette
  // **prima** di runApp come le altre (la sezione le mostra al primo fotogramma,
  // e il pianificatore le vuole quando parte).
  final notifiche = NotificationSettingsController(database.settings)..load();
  // Chi tiene allineati gli avvisi del sistema con quelli che ci devono essere.
  // Il sink è anche esposto alla UI: la sezione delle impostazioni gli chiede il
  // permesso e lo stato, e non deve conoscere il plugin.
  final aperturaNotifica = NotificationOpen();
  final sinkNotifiche = FlutterLocalNotificationsSink(
    onOpen: aperturaNotifica.ricevi,
  );
  final promemoria = NotificationScheduler(database, notifiche, sinkNotifiche);
  // Le categorie si seminano **prima** del controller: una libreria vuota al
  // primo avvio riceve le otto suggerite, e il controller le legge già dentro
  // (`category_seed.dart`). Una volta sola per device, e mai sopra una libreria
  // che ha già qualcosa dentro.
  seminaCategorieSuggerite(database);
  // La libreria delle categorie: si carica qui e converte (una volta sola) la
  // vecchia colonna di testo dei todo — chi arrivava da una versione precedente
  // non perde le etichette che aveva scritto.
  final categories = CategoryController(database);
  // Il filtro della scheda Todo: una lente che si usa per guardare, quindi una
  // preferenza del device come il tema.
  final todoFilter = TodoFilterController(database.settings)..load();
  // Il filtro condiviso fra agenda e calendario: stessa natura (una lente
  // per-device), quindi stessa strada.
  final filtroCondiviso = FiltroCondivisoController(database.settings)..load();
  // Le copie di sicurezza: la prima parte da sola dopo il primo fotogramma
  // (`BackupGuard`), e da li' in poi una al giorno se qualcosa cambia.
  final copie =
      BackupController(database, settings, servizio: copieDiSicurezza);

  // Initialize services
  final authService = AuthService();
  late final SyncService syncService;
  final attachments = NoteAttachmentStore(
    database,
    Directory(p.join(File(database.path).parent.path, 'note-attachments')),
    remote: () {
      final gateway = syncService.activeGateway;
      return gateway is EncryptedSyncGateway ? gateway : null;
    },
  );
  syncService =
      SyncService(database, files: NoteAttachmentSync(database, attachments));

  final SyncAuthService syncAuth = Platform.isAndroid &&
          !devTools &&
          const bool.fromEnvironment('PLANNER_DRIVE_OAUTH')
      ? AndroidDriveAuthService()
      : const UnconfiguredSyncAuthService();
  final syncController = SyncController(
    auth: syncAuth,
    sync: syncService,
    createGateway: () => DriveSyncGateway(auth: syncAuth),
    createFreshArchive: (gateway, beforeInitialize) async {
      final vault =
          EncryptedSyncGateway(gateway, await attachments.archiveKey());
      await vault.requireCompatibleArchive(SyncManifest.filePath,
          beforeInitialize: beforeInitialize);
      return vault;
    },
    restoreAccount:
        syncAuth is AndroidDriveAuthService ? syncAuth.restore : null,
    canPoll: () =>
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    onPulled: () {
      final scope = naveDaWidget.currentContext;
      scope?.read<EventProvider>().reload();
      scope?.read<TodoProvider>().reload();
      scope?.read<NoteProvider>().reload();
      scope?.read<CategoryController>().load();
      scope?.read<PaletteController>().load();
    },
    configureGateway: (gateway) async {
      if (gateway is! SyncAttachmentTransport) {
        throw StateError('Il gateway deve supportare gli allegati.');
      }
      final existing = await EncryptedSyncGateway.alreadyInitialized(gateway);
      if (!existing && syncService.hasArchiveBinding) {
        throw DriveArchiveMissing();
      }
      if (existing) {
        try {
          await attachments.existingArchiveKey();
        } on StateError {
          throw ArchiveRecoveryRequired(
            'Usa la chiave di Acta per aprire l’archivio già presente su Drive.',
          );
        }
      }
      final vault =
          EncryptedSyncGateway(gateway, await attachments.archiveKey());
      await vault.requireCompatibleArchive(SyncManifest.filePath,
          requireExisting: existing || syncService.hasArchiveBinding);
      return vault;
    },
  );

  runApp(
    MultiProvider(
      providers: [
        if (Platform.isAndroid &&
            kReleaseMode &&
            !devTools &&
            const bool.fromEnvironment('ACTA_GITHUB_UPDATES',
                defaultValue: true))
          ChangeNotifierProvider(create: (_) => UpdateController()),
        Provider.value(value: attachments),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: notifiche),
        Provider<NotificationScheduler>.value(value: promemoria),
        Provider<NotificationSink>.value(value: sinkNotifiche),
        ChangeNotifierProvider.value(value: aperturaNotifica),
        ChangeNotifierProvider.value(value: palettes),
        ChangeNotifierProvider.value(value: categories),
        ChangeNotifierProvider.value(value: todoFilter),
        ChangeNotifierProvider.value(value: filtroCondiviso),
        ChangeNotifierProvider.value(value: copie),
        ChangeNotifierProvider(create: (_) => EventProvider(database)),
        ChangeNotifierProvider(create: (_) => TodoProvider(database)),
        // Chi e' selezionato nella scheda Todo: sta **sopra** il guscio perche' il
        // tasto indietro — che lo gestisce lui — deve chiudere la selezione invece
        // di cambiare scheda.
        ChangeNotifierProvider(create: (_) => SelezioneDeiTodo()),
        ChangeNotifierProvider(create: (_) => SelezioneDelleNote()),
        // Il giorno chiesto dal widget mensile: sta sopra il guscio perché il
        // tocco arriva dal sistema e la scheda del calendario può non esistere
        // ancora.
        ChangeNotifierProvider<GiornoRichiesto>.value(value: giornoRichiesto),
        ChangeNotifierProvider(create: (_) => NoteProvider(database)),
        ChangeNotifierProvider.value(value: syncController),
        Provider.value(value: syncService),
        Provider.value(value: authService),
        Provider.value(value: database),
      ],
      // Il guscio sta **dentro** i tre guardiani: gli avvisi si ricalcolano dopo
      // il primo fotogramma (e a ogni modifica), i widget della schermata home si
      // riscrivono per gli stessi motivi, la copia automatica parte dopo il primo
      // fotogramma, e in pausa il WAL rientra nel file principale.
      child: const WidgetGuard(
        child: ReminderGuard(child: BackupGuard(child: AppShell())),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    syncController.restoreConnection();
  });
}
