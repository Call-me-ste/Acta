import 'event_occurrence.dart';

/// Un evento posizionato in una giornata: corsia, inizio e fine **limitati** al
/// giorno. Una barra che esce dalla griglia non si capisce, quindi si taglia.
class PlacedEvent {
  const PlacedEvent({
    required this.occurrence,
    required this.lane,
    required this.start,
    required this.end,
  });

  final EventOccurrence occurrence;

  /// La colonna assegnata: due eventi sovrapposti non si disegnano uno sopra
  /// l'altro.
  final int lane;

  final DateTime start;
  final DateTime end;

  /// Minuti dall'inizio della giornata, letti dall'**orologio**: `start` è già
  /// limitato al giorno, quindi l'ora locale *è* l'offset (e l'ora legale non
  /// sposta niente).
  int get offsetMinutes => start.hour * 60 + start.minute;

  /// Durata in minuti reali: `end` può essere la mezzanotte successiva.
  int get durationMinutes {
    final minutes = end.difference(start).inMinutes;
    return minutes < 1 ? 1 : minutes;
  }
}

/// Dove cadono gli eventi di una giornata: la parte di calcolo, senza widget.
///
/// Sta in `features/` e non nella UI perché è logica, e perché così si verifica
/// con un test puro invece che guardando uno schermo.
class DayLayout {
  const DayLayout._();

  /// Le corsie della giornata per **intervalli generici** in minuti dalla
  /// mezzanotte (già limitati al giorno, con `fine > inizio`): primo-che-sta.
  ///
  /// È la regola unica di questo file: eventi e todo con orario passano da
  /// qui, così una casella non finisce mai **sopra** un'altra. La lista viene
  /// ordinata per inizio solo internamente — il risultato resta **nell'ordine
  /// dato**, che è quello con cui i blocchi vengono disegnati.
  ///
  /// ponytail: first-fit, non l'algoritmo a gruppi. Costa O(n) e l'unico difetto
  /// è una corsia in più quando tre o più blocchi si sovrappongono fra loro.
  static List<int> corsie(List<(int, int)> intervalli) {
    final ordine = [for (var i = 0; i < intervalli.length; i++) i]
      ..sort((a, b) {
        final perInizio = intervalli[a].$1.compareTo(intervalli[b].$1);
        // Stabile fra due blocchi che cominciano insieme: primo arrivato, prima
        // servito — così il disegno non salta fra due ricostruzioni.
        return perInizio != 0 ? perInizio : a.compareTo(b);
      });

    final fineCorsie = <int>[];
    final risultato = List<int>.filled(intervalli.length, 0);
    for (final i in ordine) {
      final (inizio, fine) = intervalli[i];
      var lane = fineCorsie.indexWhere((fineLibera) => fineLibera <= inizio);
      if (lane < 0) {
        fineCorsie.add(fine);
        lane = fineCorsie.length - 1;
      } else {
        fineCorsie[lane] = fine;
      }
      risultato[i] = lane;
    }
    return risultato;
  }

  /// Quante corsie servono, date le loro assegnazioni: la più alta, più una
  /// (lista vuota → 1, come [columnsFor]: nessun elemento non è zero colonne).
  static int quante(List<int> corsie) {
    var highest = 0;
    for (final lane in corsie) {
      if (lane > highest) highest = lane;
    }
    return highest + 1;
  }

  /// Limita gli eventi al giorno e assegna le corsie col **primo che sta**
  /// (first-fit): è [corsie] sugli intervalli già clamped al giorno.
  static List<PlacedEvent> place(
    List<EventOccurrence> occurrences, {
    required DateTime day,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);
    // La fine del giorno si calcola sommando al **campo** del calendario: con
    // l'ora legale una giornata non dura 24 ore.
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    final sorted = List<EventOccurrence>.of(occurrences)
      ..sort((a, b) => a.start.compareTo(b.start));

    final clamped = <(EventOccurrence, DateTime, DateTime)>[];
    for (final occurrence in sorted) {
      final start =
          occurrence.start.isBefore(dayStart) ? dayStart : occurrence.start;
      final end = occurrence.end.isAfter(dayEnd) ? dayEnd : occurrence.end;
      // Evento degenere o interamente fuori dal giorno: non c'è niente da
      // disegnare.
      if (!end.isAfter(start)) continue;
      clamped.add((occurrence, start, end));
    }

    final lane = corsie([
      for (final (_, start, end) in clamped)
        (
          start.difference(dayStart).inMinutes,
          end.difference(dayStart).inMinutes,
        ),
    ]);
    return [
      for (final (i, (occurrence, start, end)) in clamped.indexed)
        PlacedEvent(
          occurrence: occurrence,
          lane: lane[i],
          start: start,
          end: end,
        ),
    ];
  }

  /// Quante colonne servono: la corsia più alta usata, più una.
  static int columnsFor(List<PlacedEvent> placed) {
    var highest = 0;
    for (final item in placed) {
      if (item.lane > highest) highest = item.lane;
    }
    return highest + 1;
  }
}
