import 'domain/reminder_plan.dart';
import 'notification_settings_controller.dart';

/// Chi **pianifica davvero** un avviso: l'unico punto in cui l'app parla con il
/// sistema operativo.
///
/// Esiste per una ragione sola: nei test — e sul desktop, dove non c'è niente
/// da svegliare — il pianificatore dei promemoria (che è logica) deve poter
/// girare lo stesso. L'implementazione vera è `FlutterLocalNotificationsSink`
/// (l'unico file che importa il plugin); nei test c'è una finta
/// (`test/support/fake_notification_sink.dart`).
abstract interface class NotificationSink {
  /// Prepara il minimo: il plugin e il **fuso orario**. Si chiama prima di
  /// pianificare e non fa niente la seconda volta.
  Future<void> prepara();

  /// Se il permesso di mandare notifiche c'è già. Su Android 13+ si chiede, e
  /// prima di chiederlo l'app deve sapere se serve.
  Future<bool> permessoConcesso();

  /// Lo **chiede** all'utente. Torna vero se ha accettato.
  Future<bool> chiediPermesso();

  /// Apre le impostazioni delle notifiche di questa app nel sistema: è l'unica
  /// strada quando il permesso è stato negato per sempre (da lì in poi Android
  /// non mostra più la richiesta).
  Future<void> apriImpostazioniNotifiche();

  /// Se il sistema lascia pianificare con l'allarme **esatto**. Quando è falso
  /// gli avvisi si pianificano lo stesso, ma possono arrivare in ritardo di
  /// qualche minuto, e Impostazioni lo dice invece di tacere.
  Future<bool> puoPianificareEsatto();

  /// Pianifica l'avviso. Il canale che serve lo sceglie e lo crea il sink, e la
  /// creazione è idempotente: lo stesso canale chiesto due volte resta uno.
  Future<void> pianifica(
    ScheduledReminder avviso,
    NotificationSettingsController notifiche,
  );

  /// Annulla un avviso per id. Annullare un id che non c'è **non** è un errore:
  /// è quello che succede quando un avviso è già scattato.
  Future<void> annulla(int id);

  /// **Quello che il sistema ha adesso**, per id: il valore è il carico
  /// dell'avviso (`caricoAvviso`), che porta dentro anche l'istante.
  ///
  /// È la verità con cui il pianificatore riconcilia: una tabella nostra si
  /// disallineerebbe al primo riavvio, questa no. Serve anche l'istante — non
  /// solo l'id — perché un evento **spostato** tiene lo stesso id ma deve
  /// suonare a un'ora diversa.
  Future<Map<int, String>> pianificati();
}
