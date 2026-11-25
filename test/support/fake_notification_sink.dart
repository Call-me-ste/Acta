import 'package:planner/features/notifications/domain/reminder_plan.dart';
import 'package:planner/features/notifications/notification_channels.dart';
import 'package:planner/features/notifications/notification_settings_controller.dart';
import 'package:planner/features/notifications/notification_sink.dart';

/// Il sink **finto**: tiene gli avvisi in una mappa, come farebbe Android, e
/// risponde alle domande sui permessi con quello che il test decide.
///
/// È il pezzo che rende provabile il pianificatore: senza questo, ogni prova
/// sulla riconciliazione vorrebbe un telefono collegato, e la logica più
/// delicata dell'app (quale avviso c'è, quale no) resterebbe senza test.
class FakeNotificationSink implements NotificationSink {
  /// Gli avvisi che «Android» ha adesso, per id.
  final Map<int, ScheduledReminder> avvisi = {};

  /// I carichi degli avvisi pianificati: è la parte che si confronta nella
  /// riconciliazione (id **e** carico, che porta dentro l'istante).
  final Map<int, String> carichi = {};

  /// Gli id dei canali che sono stati creati, nell'ordine: serve a provare che
  /// un avviso muto usa il canale **silenzioso** del suo tipo.
  final List<String> canali = [];

  /// Cosa risponde il sistema: il permesso, l'allarme esatto.
  bool permesso = true;
  bool esatto = true;

  int richiesteDiPermesso = 0;
  int preparazioni = 0;
  bool impostazioniAperte = false;

  @override
  Future<void> prepara() async => preparazioni++;

  @override
  Future<bool> permessoConcesso() async => permesso;

  @override
  Future<bool> chiediPermesso() async {
    richiesteDiPermesso++;
    return permesso;
  }

  @override
  Future<void> apriImpostazioniNotifiche() async => impostazioniAperte = true;

  @override
  Future<bool> puoPianificareEsatto() async => esatto;

  @override
  Future<void> pianifica(
    ScheduledReminder avviso,
    NotificationSettingsController notifiche,
  ) async {
    avvisi[avviso.id] = avviso;
    carichi[avviso.id] = caricoAvviso(avviso, notifiche);
    canali.add(canalePerAvviso(avviso, notifiche).id);
  }

  @override
  Future<void> annulla(int id) async {
    avvisi.remove(id);
    carichi.remove(id);
  }

  @override
  Future<Map<int, String>> pianificati() async => Map.of(carichi);
}
