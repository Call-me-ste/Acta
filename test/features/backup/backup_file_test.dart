import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/backup/domain/backup_file.dart';

/// Nome e foglio di una copia: le due cose che sbagliano **in silenzio**.
///
/// Una copia con un nome che non riconosciamo piu' non viene elencata e non
/// viene cancellata dalla rotazione (resta li' per sempre, o sparisce per
/// sbaglio); un foglio scritto male fa sparire dalla pagina delle copie che ci
/// sono davvero. Nessuno dei due casi fa rumore: per questo stanno qui.
void main() {
  group('il nome', () {
    test('si scrive e si rilegge', () {
      final quando = DateTime(2026, 9, 23, 20, 15, 7);
      final nome = BackupNaming.nome(quando);

      expect(nome, 'planner-20260923-201507.sqlite');
      expect(BackupNaming.quandoDi(nome), quando);
      expect(BackupNaming.duplicatoDi(nome), 0);
      expect(BackupNaming.eNostro(nome), isTrue);
    });

    test('la seconda copia dello stesso secondo ha un numero in piu', () {
      final quando = DateTime(2026, 9, 23, 20, 15, 7);
      final secondo = BackupNaming.nome(quando, duplicato: 2);

      expect(secondo, 'planner-20260923-201507-2.sqlite');
      expect(BackupNaming.quandoDi(secondo), quando);
      expect(BackupNaming.duplicatoDi(secondo), 2);
    });

    test('il foglio si chiama come la copia', () {
      expect(
        BackupNaming.foglioDi('planner-20260923-201507.sqlite'),
        'planner-20260923-201507.sqlite.json',
      );
    });

    test('i nomi che non sono nostri si rifiutano', () {
      const estranei = [
        'planner.sqlite',
        'planner-20260923.sqlite',
        'planner-2026-09-23-201507.sqlite',
        'backup-20260923-201507.sqlite',
        'planner-20260923-201507.sqlite.bak',
        // Le copie di emergenza hanno nome fisso: la loro data sta nel foglio,
        // e non devono passare per copie datate (la rotazione le toccherebbe).
        'planner-emergenza-A.sqlite',
      ];

      for (final nome in estranei) {
        expect(BackupNaming.eNostro(nome), isFalse, reason: nome);
        expect(BackupNaming.quandoDi(nome), isNull, reason: nome);
      }
    });

    test('una data impossibile non e\' una copia nostra', () {
      // Sembrano nomi nostri: un `DateTime` li accetterebbe spostandoli di
      // giorno, e la rotazione cancellerebbe per prima una copia datata male.
      const impossibili = [
        'planner-20261301-120000.sqlite', // mese 13
        'planner-20260231-120000.sqlite', // 31 febbraio
        'planner-20260923-250000.sqlite', // ora 25
        'planner-20260923-126100.sqlite', // minuto 61
      ];

      for (final nome in impossibili) {
        expect(BackupNaming.quandoDi(nome), isNull, reason: nome);
      }
    });
  });

  group('il foglio di accompagnamento', () {
    final foglio = BackupSidecar(
      appVersion: '1.1.0+2',
      schemaVersion: 1,
      createdAt: DateTime(2026, 9, 23, 20, 15, 7),
      device: 'android',
      counts: const {'events': 45, 'todos': 158},
      checksum: 'deadbeefdeadbeef',
      reason: BackupReason.preAggiornamento,
    );

    test('si scrive e si rilegge senza perdere niente', () {
      final letto = BackupSidecar.fromJson(foglio.toJson())!;

      expect(letto.appVersion, '1.1.0+2');
      expect(letto.schemaVersion, 1);
      expect(letto.createdAt, foglio.createdAt);
      expect(letto.device, 'android');
      expect(letto.counts, {'events': 45, 'todos': 158});
      expect(letto.checksum, 'deadbeefdeadbeef');
      expect(letto.reason, BackupReason.preAggiornamento);
    });

    test('un foglio senza l\'essenziale si rifiuta invece di esplodere', () {
      expect(BackupSidecar.fromJson(null), isNull);
      expect(BackupSidecar.fromJson('non un foglio'), isNull);
      expect(BackupSidecar.fromJson(const {}), isNull);
      // Il checksum e' l'essenziale: senza, la copia non e' verificabile.
      expect(
        BackupSidecar.fromJson(const {
          'app_version': '1.1.0+2',
          'schema_version': 1,
          'created_at': 1,
        }),
        isNull,
      );
    });

    test('i campi sporchi non portano via il foglio intero', () {
      final letto = BackupSidecar.fromJson(const {
        'app_version': '1.1.0+2',
        'schema_version': 1,
        'created_at': 1000,
        'checksum': 'abc123',
        // `counts` con dentro spazzatura e `reason` scritta da una versione che
        // non conosciamo: il foglio deve restare leggibile.
        'counts': {'events': 45, 'rotta': 'molte', 7: 1},
        'reason': 'motivo-di-una-versione-futura',
      })!;

      expect(letto.counts, {'events': 45});
      expect(letto.reason, isNull);
      expect(letto.device, 'sconosciuto');
    });

    test('un backup piu\' nuovo non si apre, uno piu\' vecchio si', () {
      expect(foglio.compatibile(1), isTrue);
      expect(foglio.compatibile(2), isTrue,
          reason: 'colonne in piu\' non ci sono');
      expect(foglio.compatibile(0), isFalse,
          reason: 'schema piu\' nuovo del nostro');
    });

    test('un motivo sconosciuto non si spaccia per automatico', () {
      expect(BackupReason.daNome('preRipristino'), BackupReason.preRipristino);
      expect(BackupReason.daNome(null), isNull);
      expect(BackupReason.daNome('altro'), isNull);
    });
  });

  test('una copia di emergenza si riconosce dal nome, anche senza foglio', () {
    final emergenza = BackupFile(
      name: BackupNaming.emergenzaA,
      createdAt: DateTime(2026, 9, 23),
      sizeBytes: 100,
      sidecar: null,
    );
    final normale = BackupFile(
      name: 'planner-20260923-201507.sqlite',
      createdAt: DateTime(2026, 9, 23, 20, 15, 7),
      sizeBytes: 100,
      sidecar: null,
    );

    expect(emergenza.eEmergenza, isTrue);
    expect(emergenza.reason, BackupReason.emergenza);
    expect(normale.eEmergenza, isFalse);
    expect(normale.reason, isNull,
        reason: 'senza foglio il motivo non si inventa');
  });
}
