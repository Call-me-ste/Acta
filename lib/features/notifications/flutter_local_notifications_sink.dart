import 'dart:io' show Platform;
import 'dart:ui' show Color, DartPluginRegistrant;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as dati_del_fuso;
import 'package:timezone/timezone.dart' as fuso;

import '../../core/database/database_service.dart';
import 'domain/reminder_plan.dart';
import 'notification_actions.dart';
import 'notification_scheduler.dart';
import 'notification_channels.dart';
import 'notification_settings_controller.dart';
import 'notification_presentation.dart';
import 'notification_sink.dart';

/// L'implementazione vera del sink: **l'unico file che importa il plugin**.
///
/// Il plugin è una dipendenza di piattaforma (metodi nativi, un canale per
/// piattaforma, due receiver nel manifest) e il resto dell'app non deve sapere
/// che esiste: chi vuole provare la pianificazione usa la finta nei test.
///
/// Tre cose che il plugin **non** fa da solo, e che stanno qui:
/// - il **fuso orario**: `zonedSchedule` vuole un istante in `tz.local`, e senza
///   `setLocalLocation` il fuso del processo Dart parte da UTC — cioè gli avvisi
///   spostati di una o due ore;
/// - l'**icona della barra di stato**: deve essere una sagoma monocromatica
///   (`res/drawable/ic_notifica.xml`), non l'icona dell'app, che verrebbe
///   disegnata come un quadrato pieno;
/// - il **modo** di pianificazione: esatto se il sistema lo concede
///   (`USE_EXACT_ALARM`), inesatto altrimenti — e chi legge lo stato lo dice
///   all'utente invece di tacere.
///
/// I canali non si creano qui a mano: `AndroidNotificationChannelAction.
/// createIfNotExists` li crea la prima volta che un avviso li usa, e chiedere due
/// volte lo stesso canale lascia un canale solo.
class FlutterLocalNotificationsSink implements NotificationSink {
  FlutterLocalNotificationsSink({
    FlutterLocalNotificationsPlugin? plugin,
    this.onOpen,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String payload)? onOpen;
  bool _pronto = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> prepara() async {
    if (_pronto) return;

    // Le notifiche di questo incremento sono per **Android**: sul desktop la
    // shell non esiste ancora e il plugin là ha un'implementazione sua che non
    // usiamo (è una delle cose dichiarate «fuori scope» nella specifica). Sul
    // desktop il sink resta **inerte** — non pianifica e non chiede niente —
    // invece di far cadere l'avvio dell'app per un fuso orario che non serve.
    if (!Platform.isAndroid) {
      _pronto = true;
      return;
    }

    dati_del_fuso.initializeTimeZones();
    final locale = await FlutterTimezone.getLocalTimezone();
    fuso.setLocalLocation(fuso.getLocation(locale.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notifica'),
      ),
      onDidReceiveNotificationResponse: (risposta) => _apri(risposta.payload),
      onDidReceiveBackgroundNotificationResponse: _azioneNotificaAndroid,
    );

    if (onOpen != null) {
      final avvio = await _plugin.getNotificationAppLaunchDetails();
      if (avvio?.didNotificationLaunchApp ?? false) {
        _apri(avvio?.notificationResponse?.payload);
      }
    }
    _pronto = true;
  }

  void _apri(String? payload) {
    if (payload != null && payload.isNotEmpty) onOpen?.call(payload);
  }

  @override
  Future<bool> permessoConcesso() async {
    final android = _android;
    // Sul desktop non c'è niente da concedere: le notifiche o ci sono o non ci
    // sono, e non è una cosa che si approva.
    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> chiediPermesso() async {
    final android = _android;
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> apriImpostazioniNotifiche() async {
    await _android?.openAppNotificationSettings();
  }

  @override
  Future<bool> puoPianificareEsatto() async {
    final android = _android;
    if (android == null) return false;
    return await android.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> pianifica(
    ScheduledReminder avviso,
    NotificationSettingsController notifiche,
  ) async {
    await prepara();

    final canale = canalePerAvviso(avviso, notifiche);
    final esatto = await puoPianificareEsatto();
    final testo = descriviPromemoria(avviso);

    await _plugin.zonedSchedule(
      id: avviso.id,
      title: titoloPromemoria(avviso),
      body: testo,
      scheduledDate: fuso.TZDateTime.from(avviso.when, fuso.local),
      notificationDetails: NotificationDetails(
        android: _dettagli(canale, notifiche, testo, avviso),
      ),
      androidScheduleMode: esatto
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      payload: caricoAvviso(avviso, notifiche),
    );
  }

  @override
  Future<void> annulla(int id) async {
    await prepara();
    await _plugin.cancel(id: id);
  }

  @override
  Future<Map<int, String>> pianificati() async {
    await prepara();
    final attesi = await _plugin.pendingNotificationRequests();
    return {
      for (final avviso in attesi) avviso.id: avviso.payload ?? '',
    };
  }

  /// La forma dell'avviso: il canale (che è quello che decide voce e
  /// importanza), il contenuto sulla schermata di blocco e il tocco che chiude
  /// la notifica da sola.
  AndroidNotificationDetails _dettagli(
    CanaleAvviso canale,
    NotificationSettingsController notifiche,
    String testo,
    ScheduledReminder avviso,
  ) {
    return AndroidNotificationDetails(
      canale.id,
      canale.nome,
      channelDescription: canale.descrizione,
      category: AndroidNotificationCategory.reminder,
      icon:
          avviso.kind == ReminderKind.todo ? 'ic_notifica_todo' : 'ic_notifica',
      color: const Color(0xFF087F7C),
      styleInformation: BigTextStyleInformation(testo),
      actions: [
        if (avviso.itemDate != null || avviso.kind == ReminderKind.riepilogo)
          AndroidNotificationAction(
            'apri-elemento',
            switch (avviso.kind) {
              ReminderKind.todo => 'Apri',
              ReminderKind.riepilogo => 'Vedi scaduti',
              _ => 'Apri evento',
            },
            showsUserInterface: true,
          ),
        if (avviso.itemDate != null)
          const AndroidNotificationAction(
            notificationSnoozeAction,
            'Rimanda 10 min',
            cancelNotification: false,
          ),
        if (avviso.kind == ReminderKind.todo && avviso.itemDate != null)
          const AndroidNotificationAction(
            notificationDoneAction,
            'Fatto',
            cancelNotification: false,
          ),
      ],
      importance: _importanza(canale.importanza),
      priority: _priorita(canale.importanza),
      playSound: canale.suona,
      sound: canale.suonoUri == null
          ? null
          : UriAndroidNotificationSound(canale.suonoUri!),
      enableVibration: canale.vibra,
      visibility: _visibilita(notifiche.blocco),
      channelAction: AndroidNotificationChannelAction.createIfNotExists,
    );
  }

  /// L'importanza di Android (2 bassa, 3 media, 4 alta) tradotta nell'enum del
  /// plugin. Il numero vive in `notification_channels.dart`, che è puro: qui si
  /// traduce e basta.
  static Importance _importanza(int valore) => switch (valore) {
        2 => Importance.low,
        4 => Importance.high,
        _ => Importance.defaultImportance,
      };

  /// La stessa cosa per il `priority`, che serve solo sotto Android 8 (dove i
  /// canali non esistono e la priorità la decide la notifica).
  static Priority _priorita(int valore) => switch (valore) {
        2 => Priority.low,
        4 => Priority.high,
        _ => Priority.defaultPriority,
      };

  static NotificationVisibility _visibilita(String blocco) => switch (blocco) {
        NotificationSettingsController.bloccoPubblico =>
          NotificationVisibility.public,
        NotificationSettingsController.bloccoSegreto =>
          NotificationVisibility.secret,
        _ => NotificationVisibility.private,
      };
}

Future<void> _ultimaAzione = Future.value();

@pragma('vm:entry-point')
void _azioneNotificaAndroid(NotificationResponse risposta) {
  _ultimaAzione = _ultimaAzione.then((_) => _eseguiAzione(risposta));
}

Future<void> _eseguiAzione(NotificationResponse risposta) async {
  final payload = risposta.payload;
  final target = NotificationTarget.parse(payload);
  if (payload == null || target == null) return;

  final db = DatabaseService();
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await db.init();
    final impostazioni = NotificationSettingsController(db.settings)..load();
    final azioni = NotificationActions(db);
    final ok = switch (risposta.actionId) {
      notificationSnoozeAction => azioni.rimanda(
          target,
          payload,
          DateTime.now(),
          impostazioni,
        ),
      notificationDoneAction => azioni.completa(target),
      _ => false,
    };
    if (!ok) return;

    final sink = FlutterLocalNotificationsSink();
    final id = risposta.id;
    if (id != null) await sink.annulla(id);
    await NotificationScheduler(db, impostazioni, sink).riconcilia();
  } catch (errore) {
    debugPrint('Azione notifica Planner: $errore');
  } finally {
    db.close();
  }
}
