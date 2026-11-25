/// La **costruzione** del pacchetto mensile: pura, senza schermo e senza plugin
/// (`test/features/widgets/widget_mese_test.dart`).
///
/// Separata da `widget_snapshot.dart` per una ragione di strati: il mese non ha
/// righe, conteggi di todo né stati della giornata — ha una griglia. Tenerla in
/// un file suo evita che la logica del giorno si porti dietro 42 giorni di
/// calendario e viceversa.
library;

import 'dart:ui' show Brightness;

import '../events/domain/event_occurrence.dart';
import 'domain/widget_mese.dart';
import 'widget_contract.dart';

/// Il materiale di partenza del mese: gli eventi e le risposte che dipendono dal
/// tema.
class MaterialeDelMese {
  const MaterialeDelMese({
    required this.adesso,
    required this.eventiIntervallo,
    required this.coloreEvento,
    required this.etichettaDelMese,
  });

  /// L'istante della costruzione: serve solo a segnare il giorno di «oggi».
  final DateTime adesso;

  /// Le occorrenze nella finestra `[da, il)`, **in una passata sola**.
  ///
  /// È la ragione per cui il mese non fa 42 letture: la griglia (5-6 settimane)
  /// chiede una volta la finestra intera — mesi adiacenti compresi — e poi
  /// raggruppa in memoria. La funzione è quella del provider
  /// (`EventProvider.occurrencesBetween`), che espande anche le ricorrenze.
  final List<EventOccurrence> Function(DateTime da, DateTime il)
      eventiIntervallo;

  final String Function(EventOccurrence evento, Brightness brightness)
      coloreEvento;

  /// L'intestazione del mese: `settembre 2026`. La compone chi chiama, perché i
  /// nomi dei mesi sono nella voce dell'app (`ui/shared/formatters.dart`) e
  /// questa è logica.
  final String Function(DateTime mese) etichettaDelMese;
}

/// Il primo giorno del mese di [quando], a mezzanotte locale.
DateTime primoDelMese(DateTime quando) => DateTime(quando.year, quando.month);

/// Il mese pronto: la griglia intera, le anteprime e i conteggi veri.
///
/// La griglia comincia dal **lunedì** della settimana che contiene il primo del
/// mese (la settimana italiana) e finisce con l'ultima domenica: 4, 5 o 6 righe
/// secondo il mese. I giorni che avanzano sono quelli del mese prima e del mese
/// dopo, segnati `fuoriMese`.
WidgetMese meseDelWidget(DateTime mese, MaterialeDelMese materiale) {
  final primo = primoDelMese(mese);
  final giorniDelMese = DateTime(primo.year, primo.month + 1, 0).day;
  final scartoIniziale = primo.weekday - DateTime.monday;
  final settimane = ((scartoIniziale + giorniDelMese) / 7).ceil();
  final inizio = DateTime(primo.year, primo.month, primo.day - scartoIniziale);
  final fine = DateTime(inizio.year, inizio.month, inizio.day + settimane * 7);

  // Una passata sola, e le ricorrenze le espande il provider: la griglia non è
  // 42 domande, è una.
  final perGiorno = <DateTime, List<EventOccurrence>>{};
  for (final evento in materiale.eventiIntervallo(inizio, fine)) {
    final giorno = DateTime(evento.date.year, evento.date.month, evento.date.day);
    (perGiorno[giorno] ??= []).add(evento);
  }

  final oggi = DateTime(
    materiale.adesso.year,
    materiale.adesso.month,
    materiale.adesso.day,
  );

  final giorni = <WidgetMeseGiorno>[];
  for (var scarto = 0; scarto < settimane * 7; scarto++) {
    final data = DateTime(inizio.year, inizio.month, inizio.day + scarto);
    final eventi = perGiorno[data] ?? const <EventOccurrence>[];
    // In ordine di ora: le anteprime sono le **prime** della giornata, non le
    // prime che capitano nel database.
    final ordinati = [...eventi]..sort((a, b) => a.start.compareTo(b.start));
    giorni.add(
      WidgetMeseGiorno(
        data: dataIso(data),
        giorno: data.day,
        fuoriMese: data.month != primo.month || data.year != primo.year,
        eventi: eventi.length,
        anteprime: [
          for (final evento in ordinati.take(anteprimeNelMese))
            WidgetMeseAnteprima(
              // Un evento senza titolo non è un errore: la cella mostra il
              // colore e basta.
              titolo: evento.title,
              colore: materiale.coloreEvento(evento, Brightness.light),
              coloreScuro: materiale.coloreEvento(evento, Brightness.dark),
            ),
        ],
        oggi: data == oggi,
      ),
    );
  }

  return WidgetMese(
    anno: primo.year,
    mese: primo.month,
    etichetta: materiale.etichettaDelMese(primo),
    settimane: settimane,
    giorni: giorni,
  );
}

/// Il pacchetto dei mesi: **il corrente e gli adiacenti**, per chiave.
///
/// Tre mesi e non uno perché le frecce del widget devono funzionare con l'app
/// chiusa. È il limite dichiarato del widget: fuori da questa finestra il
/// Kotlin non ha una chiave da leggere, quindi lo dice e apre l'app — non
/// mostra giorni vecchi come se fossero attuali.
Map<DateTime, WidgetMese> pacchettoDeiMesi({
  required DateTime oggi,
  required MaterialeDelMese materiale,
  int mesi = mesiNellaFinestra,
}) {
  final corrente = primoDelMese(oggi);
  // Si parte dal mese **prima** del corrente (`mesi ~/ 2`: con tre mesi, uno
  // indietro) e si cammina in avanti.
  final primo = DateTime(corrente.year, corrente.month - (mesi ~/ 2));
  return {
    for (var scarto = 0; scarto < mesi; scarto++)
      _chiave(primo, scarto): meseDelWidget(_chiave(primo, scarto), materiale),
  };
}

DateTime _chiave(DateTime primo, int scarto) =>
    DateTime(primo.year, primo.month + scarto);
