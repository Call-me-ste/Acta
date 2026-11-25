import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../../core/database/database_files.dart';
import '../../core/sync/hash.dart';

/// L'esito della verifica di una copia.
class EsitoVerifica {
  const EsitoVerifica._(this.ok, this.problema, this.conteggi, this.checksum);

  final bool ok;

  /// Cosa non andava, quando `ok` e' falso.
  final String? problema;

  /// Le righe per tabella lette **dentro la copia**.
  final Map<String, int> conteggi;

  /// `fnv1a64` del file: cambia se cambia un solo byte.
  final String checksum;

  static EsitoVerifica nonVa(String problema, [String checksum = '']) =>
      EsitoVerifica._(false, problema, const {}, checksum);
}

/// Verifica un file di copia: si apre, e' integro, e dice quante righe ha.
///
/// Sta fuori da `backup_service.dart` perche' e' un mestiere a se': leggere un
/// file **di sola lettura** e dire se e' una copia sana non ha bisogno di sapere
/// dove stanno le copie, come si chiamano o quando le si fa. Il servizio la usa
/// per quello che scrive lui stesso, prima di dargli un nome.
///
/// In sola lettura di proposito: verificare non deve poter cambiare quello che
/// sta verificando (ne' creargli accanto un file di appoggio del WAL).
Future<EsitoVerifica> verificaCopia(File file) async {
  if (!file.existsSync()) return EsitoVerifica.nonVa('il file non c\'è');

  final checksum = await fnv1a64Stream(file.openRead());
  Database? copia;
  try {
    copia = sqlite3.open(file.path, mode: OpenMode.readOnly);

    final integrita = copia.select('PRAGMA integrity_check').first.values.first;
    if (integrita != 'ok') {
      return EsitoVerifica.nonVa(
          'il file è danneggiato ($integrita)', checksum);
    }

    final conteggi = <String, int>{};
    for (final tabella in tabelleDati) {
      // Una copia di una versione piu' vecchia puo' non avere una tabella (una
      // funzione che allora non esisteva): manca la tabella, non la copia.
      if (!_esiste(copia, tabella)) continue;
      conteggi[tabella] =
          copia.select('SELECT COUNT(*) AS n FROM $tabella').first['n'] as int;
    }
    return EsitoVerifica._(true, null, conteggi, checksum);
  } on SqliteException catch (errore) {
    return EsitoVerifica.nonVa('non si apre: ${errore.message}', checksum);
  } finally {
    copia?.dispose();
  }
}

bool _esiste(Database copia, String tabella) => copia.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tabella],
    ).isNotEmpty;
