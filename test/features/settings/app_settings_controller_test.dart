import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/palette/domain/presets.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/settings/priority_colors.dart';

void main() {
  late DatabaseService db;
  late AppSettingsController settings;

  setUp(() async {
    db = DatabaseService();
    await db.init(dbPath: ':memory:');
    settings = AppSettingsController(db.settings)..load();
  });

  tearDown(() => db.close());

  test('su un database vuoto valgono i default', () async {
    expect(settings.themeMode, AppSettingsController.themeSystem);
    expect(settings.activePaletteId, defaultPaletteId);
    expect(settings.animationsEnabled, isTrue);
    expect(settings.calendarView, CalendarView.mese);
    expect(settings.backupFolder, isNull);
    expect(
        settings.backupRetention, AppSettingsController.defaultBackupRetention);
    expect(settings.overdueWindowDays,
        AppSettingsController.defaultOverdueWindowDays);
    expect(settings.lastBackupAt, isNull);
    expect(settings.firstRunDone, isFalse);
  });

  test('le preferenze sopravvivono a un nuovo load', () async {
    settings.setThemeMode(AppSettingsController.themeDark);
    settings.setActivePalette('preset-inverno');
    settings.setAnimationsEnabled(false);
    settings.setCalendarView(CalendarView.giorno);
    settings.setBackupFolder('S:\\Backup');
    settings.setBackupRetention(25);
    settings.setOverdueWindowDays(7);
    settings.markBackupDone(DateTime(2026, 9, 14, 18, 30));

    // Le scritture sono differite di una microattivita' (fuori dal fotogramma del
    // gesto): si lascia finire il giro prima di leggere il disco.
    await pumpEventQueue();

    final reloaded = AppSettingsController(db.settings)..load();

    expect(reloaded.themeMode, AppSettingsController.themeDark);
    expect(reloaded.activePaletteId, 'preset-inverno');
    expect(reloaded.animationsEnabled, isFalse);
    expect(reloaded.calendarView, CalendarView.giorno);
    expect(reloaded.backupFolder, 'S:\\Backup');
    expect(reloaded.backupRetention, 25);
    expect(reloaded.overdueWindowDays, 7);
    expect(reloaded.lastBackupAt, DateTime(2026, 9, 14, 18, 30));
  });

  test('i valori fuori scala vengono limitati, non accettati', () async {
    settings.setBackupRetention(999);
    expect(settings.backupRetention, 50);
    settings.setBackupRetention(-4);
    expect(settings.backupRetention, 3);

    settings.setOverdueWindowDays(0);
    expect(settings.overdueWindowDays, 1);
    settings.setOverdueWindowDays(10000);
    expect(settings.overdueWindowDays, 365);
  });

  test('un valore illeggibile ricade sul default invece di rompere l\'avvio',
      () {
    db.settings.set('themeMode', 'viola');
    db.settings.set('activePaletteId', '');
    db.settings.set('backupRetention', 'molti');
    // Un valore che NON è una vista: 'settimana' lo è diventata, quindi il
    // nome finto va scelto fra quelli che non esistono (e se un giorno
    // 'dimensione' diventasse una vista, il test va aggiornato).
    db.settings.set('calendarView', 'dimensione');
    db.settings.set('lastBackupAt', 'ieri');

    final reloaded = AppSettingsController(db.settings)..load();

    expect(reloaded.themeMode, AppSettingsController.themeSystem);
    expect(reloaded.activePaletteId, defaultPaletteId);
    expect(
      reloaded.backupRetention,
      AppSettingsController.defaultBackupRetention,
    );
    expect(reloaded.calendarView, CalendarView.mese);
    expect(reloaded.lastBackupAt, isNull);
  });

  test('un tema non valido non viene scritto', () async {
    settings.setThemeMode('viola');
    expect(settings.themeMode, AppSettingsController.themeSystem);
    // Le scritture sono differite di una microattivita': si lascia
    // finire il giro prima di guardare il disco.
    await pumpEventQueue();
    expect(db.settings.get('themeMode'), isNull);
  });

  test('cancellare la cartella di backup toglie la chiave, non scrive vuoto',
      () async {
    settings.setBackupFolder('S:\\Backup');
    settings.setBackupFolder(null);
    expect(settings.backupFolder, isNull);
    // Le scritture sono differite di una microattivita': si lascia
    // finire il giro prima di guardare il disco.
    await pumpEventQueue();
    expect(db.settings.get('backupFolder'), isNull);
  });

  test('firstRunDone si marca una volta sola', () async {
    settings.markFirstRunDone();
    expect(settings.firstRunDone, isTrue);
    // Le scritture sono differite di una microattivita': si lascia
    // finire il giro prima di guardare il disco.
    await pumpEventQueue();
    expect(db.settings.get('firstRunDone'), '1');
  });

  group('colori della priorita', () {
    test('di base: azzurro, giallo, arancione, rosso', () {
      expect(settings.priorityColors, defaultPriorityColors);
      // Bassa azzurra, urgente rossa: l'ordine degli indici e' quello del
      // codice (0 Bassa ... 3 Urgente).
      expect(settings.priorityColorOf(0), defaultPriorityColors[0]);
      expect(settings.priorityColorOf(3), defaultPriorityColors[3]);
    });

    test('un colore cambiato resta, e gli indici fuori scala li porta dentro',
        () async {
      settings.setPriorityColor(2, '#123456');
      expect(settings.priorityColorOf(2), '#123456');
      // 9 non e' un livello: si porta dentro l'ultimo (Urgente) invece di
      // lanciare; -1 sul primo.
      expect(settings.priorityColorOf(9), defaultPriorityColors[3]);
      expect(settings.priorityColorOf(-1), defaultPriorityColors[0]);

      await pumpEventQueue();
      final reloaded = AppSettingsController(db.settings)..load();
      expect(reloaded.priorityColorOf(2), '#123456');
      // Gli altri tre non si toccano.
      expect(reloaded.priorityColorOf(0), defaultPriorityColors[0]);
      expect(reloaded.priorityColorOf(3), defaultPriorityColors[3]);
    });

    test('il ripristino toglie la chiave, non scrive una copia', () async {
      settings.setPriorityColor(1, '#000000');
      await pumpEventQueue();
      expect(
          db.settings.get('priorityColors'), '#4CAF50,#000000,#FF9800,#F44336');

      settings.resetPriorityColors();
      await pumpEventQueue();

      expect(settings.priorityColors, defaultPriorityColors);
      expect(db.settings.get('priorityColors'), isNull);
    });

    test('un colore rotto ricade sul suo default, gli altri restano', () {
      final letti = parsePriorityColors('#112233,ciao,, #445566');
      expect(letti, hasLength(defaultPriorityColors.length));
      expect(letti[0], '#112233');
      expect(letti[1], defaultPriorityColors[1]);
      expect(letti[2], defaultPriorityColors[2]);
      expect(letti[3], '#445566');
    });

    test('senza valori o con troppi, i livelli sono sempre quattro', () {
      expect(parsePriorityColors(null), defaultPriorityColors);
      expect(parsePriorityColors(''), defaultPriorityColors);
      expect(
        parsePriorityColors('#111111,#222222,#333333,#444444,#555555'),
        ['#111111', '#222222', '#333333', '#444444'],
      );
    });
  });
}
