import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/notifications/notification_settings_controller.dart';

/// Le **sedici preferenze** delle notifiche: i default (quelli scritti nella
/// specifica), la persistenza, e i valori storti.
///
/// Perché conta: un default sbagliato qui è un avviso che non arriva — o che
/// arriva alle 3 di notte — senza che nessuno abbia toccato niente. E il
/// `QuietHours` nullo è la differenza fra «gli avvisi in silenzio di notte» e
/// «gli avvisi sempre zitti».
void main() {
  late DatabaseService db;
  late NotificationSettingsController notifiche;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    notifiche = NotificationSettingsController(db.settings)..load();
  });

  tearDown(() => db.close());

  test('su un database vuoto valgono i default della specifica', () async {
    expect(notifiche.attive, isFalse, reason: 'di partenza sono spente');
    expect(notifiche.evento, isTrue);
    expect(notifiche.todo, isTrue);
    expect(notifiche.tuttoIlGiorno, isTrue);
    expect(notifiche.riepilogo, isFalse);
    expect(notifiche.anticipoEventi, 15);
    expect(notifiche.anticipoTodo, 0);
    expect(notifiche.oraTodo, 9 * 60);
    expect(notifiche.oraTuttoIlGiorno, 8 * 60);
    expect(notifiche.oraRiepilogo, 20 * 60);
    expect(notifiche.silenzioDa, 22 * 60);
    expect(notifiche.silenzioA, 7 * 60);
    expect(notifiche.suono, NotificationSettingsController.suonoSistema);
    expect(notifiche.suona, isTrue);
    expect(notifiche.vibraEventi, isTrue);
    expect(notifiche.vibraTodo, isTrue);
    expect(notifiche.blocco, NotificationSettingsController.bloccoPrivato);
  });

  test('un tipo è acceso solo se lo è anche l\'interruttore generale',
      () async {
    expect(notifiche.eventoAttivo, isFalse);
    expect(notifiche.todoAttivo, isFalse);

    notifiche.setAttive(true);

    expect(notifiche.eventoAttivo, isTrue);
    expect(notifiche.todoAttivo, isTrue);

    notifiche.setTodo(false);

    expect(notifiche.eventoAttivo, isTrue);
    expect(notifiche.todoAttivo, isFalse);
  });

  test('il riepilogo conserva le preferenze delle installazioni precedenti',
      () {
    db.settings.set(NotificationSettingsController.notificheAttiveKey, '1');
    notifiche.load();
    expect(notifiche.riepilogo, isTrue);
    db.settings.set(NotificationSettingsController.riepilogoKey, '0');
    notifiche.load();
    expect(notifiche.riepilogo, isFalse);
  });

  test('le preferenze sopravvivono a un nuovo load', () async {
    notifiche.setAttive(true);
    notifiche.setRiepilogo(false);
    notifiche.setAnticipoEventi(30);
    notifiche.setOraTodo(7 * 60 + 30);
    notifiche.setSilenzio(da: 23 * 60 + 30, a: 6 * 60);
    notifiche.setSuono(NotificationSettingsController.suonoNessuno);
    notifiche.setVibraTodo(false);
    notifiche.setBlocco(NotificationSettingsController.bloccoSegreto);

    // Le scritture sono differite di una microattività: si lascia finire il giro.
    await pumpEventQueue();

    final rilette = NotificationSettingsController(db.settings)..load();

    expect(rilette.attive, isTrue);
    expect(rilette.riepilogo, isFalse);
    expect(rilette.evento, isTrue, reason: 'non toccato: resta il default');
    expect(rilette.anticipoEventi, 30);
    expect(rilette.oraTodo, 7 * 60 + 30);
    expect(rilette.silenzioDa, 23 * 60 + 30);
    expect(rilette.silenzioA, 6 * 60);
    expect(rilette.suono, NotificationSettingsController.suonoNessuno);
    expect(rilette.suona, isFalse);
    expect(rilette.vibraTodo, isFalse);
    expect(rilette.blocco, NotificationSettingsController.bloccoSegreto);
  });

  test('le ore silenziose spente sono null, non un intervallo vuoto', () {
    notifiche.setSilenzio(da: 22 * 60, a: 22 * 60);

    expect(notifiche.quietHours, isNull);

    notifiche.setSilenzio(da: 22 * 60, a: 7 * 60);

    expect(notifiche.quietHours, isNotNull);
    expect(notifiche.quietHours!.start, 22 * 60);
    expect(notifiche.quietHours!.end, 7 * 60);
  });

  test('i valori storti cadono sui default invece di rompere', () {
    db.settings.set(NotificationSettingsController.oraTodoKey, 'sette e mezza');
    db.settings.set(NotificationSettingsController.silenzioDaKey, '-100');
    db.settings.set(NotificationSettingsController.suonoKey, 'trombette');
    db.settings.set(NotificationSettingsController.bloccoKey, 'boh');
    db.settings
        .set(NotificationSettingsController.anticipoEventiKey, '99999999');

    final lette = NotificationSettingsController(db.settings)..load();

    expect(lette.oraTodo, NotificationSettingsController.oraTodoDefault);
    expect(lette.silenzioDa, 0, reason: 'fuori scala: si lima, non si scarta');
    expect(lette.suono, NotificationSettingsController.suonoSistema);
    expect(lette.blocco, NotificationSettingsController.bloccoPrivato);
    expect(
      lette.anticipoEventi,
      7 * 24 * 60,
      reason: 'un anticipo assurdo si lima al massimo',
    );
  });

  test('un suono che non esiste non si salva', () {
    notifiche.setSuono('trombette');

    expect(notifiche.suono, NotificationSettingsController.suonoSistema);
    expect(db.settings.get(NotificationSettingsController.suonoKey), isNull);
  });
}
