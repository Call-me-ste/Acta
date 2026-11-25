/// La **costruzione** del pacchetto dei widget: pura, senza schermo e senza
/// plugin (`test/features/widgets/widget_snapshot_test.dart`).
///
/// Prende i dati di otto giorni già letti e ne fa quello che il renderer Kotlin
/// deve solo disegnare. Qui stanno le decisioni che si **vedono**: l'ordine delle
/// righe, quando una giornata è «vuota» o «tutta fatta», cosa vuol dire «in
/// corso», e i conteggi veri dietro il taglio delle righe.
library;

import 'dart:ui' show Brightness;

import '../events/domain/event_occurrence.dart';
import '../todos/domain/todo.dart';
import '../todos/domain/todo_order.dart';
import 'domain/widget_payload.dart';
import 'widget_contract.dart';

/// Il materiale di partenza: i dati per giorno, e le risposte che dipendono dal
/// tema e dalle categorie — che qui non si possono conoscere.
class MaterialeDelWidget {
  const MaterialeDelWidget({
    required this.adesso,
    required this.eventiDelGiorno,
    required this.todoDelGiorno,
    required this.todoFatto,
    required this.coloreEvento,
    required this.coloreTodo,
    required this.emoji,
    required this.etichettaDelGiorno,
  });

  /// L'istante della costruzione: serve a «in corso adesso» e a chiudere la
  /// giornata quando gli eventi sono finiti.
  final DateTime adesso;

  final List<EventOccurrence> Function(DateTime giorno) eventiDelGiorno;
  final List<Todo> Function(DateTime giorno) todoDelGiorno;

  /// Vero se quel todo è fatto **in quel giorno** (`isDoneOn`): per un ricorrente
  /// è l'occorrenza, per uno singolo è il todo.
  final bool Function(Todo todo, DateTime giorno) todoFatto;

  final String Function(EventOccurrence evento, Brightness brightness)
      coloreEvento;
  final String Function(Todo todo, Brightness brightness) coloreTodo;

  /// L'emoji della prima categoria di un elemento (vuota se non ne ha).
  final String Function(List<String> categoryIds) emoji;

  /// L'intestazione del giorno: `Oggi · gio 24 set`.
  ///
  /// La compone chi chiama (`ui/shared/widget_guard.dart`): i nomi dei giorni e
  /// dei mesi stanno nella voce dell'app (`ui/shared/formatters.dart`) e la
  /// logica — che è questo file — non importa la UI.
  final String Function(DateTime giorno) etichettaDelGiorno;
}

/// Il giorno pronto: righe ordinate, conteggi veri, stato.
WidgetGiorno giornoDelWidget(DateTime giorno, MaterialeDelWidget materiale) {
  final eventi = materiale.eventiDelGiorno(giorno);
  final todo = materiale.todoDelGiorno(giorno);
  final oggi = _stessoGiorno(giorno, materiale.adesso);

  final conOra = <({int minuti, int indice, WidgetRow riga})>[];
  final senzaOra = <WidgetRow>[];
  var indice = 0;

  for (final evento in eventi) {
    final tuttoIlGiorno = evento.event.allDay;
    final riga = WidgetRow(
      id: evento.event.id,
      tipo: tipoEvento,
      titolo: evento.title,
      ora: tuttoIlGiorno ? '' : _oraDi(evento.start),
      colore: materiale.coloreEvento(evento, Brightness.light),
      coloreScuro: materiale.coloreEvento(evento, Brightness.dark),
      tuttoIlGiorno: tuttoIlGiorno,
      emoji: materiale.emoji(evento.event.categoryIds),
      inCorso: oggi &&
          !tuttoIlGiorno &&
          !evento.start.isAfter(materiale.adesso) &&
          evento.end.isAfter(materiale.adesso),
    );
    if (tuttoIlGiorno) {
      senzaOra.add(riga);
    } else {
      conOra.add((
        minuti: evento.start.hour * 60 + evento.start.minute,
        indice: indice,
        riga: riga
      ));
    }
    indice++;
  }

  // I todo senza orario vengono **dopo** gli eventi senza orario, e fra loro
  // nell'ordine della scheda Todo (`confrontaTodo`): la stessa regola, non una
  // copia che si allontana.
  final senzaOraTodo = <Todo>[];
  for (final todo in todo) {
    final inizio = todo.startMinutes;
    final fine = todo.endMinutes;
    final riga = WidgetRow(
      id: todo.id,
      tipo: tipoTodo,
      titolo: todo.title,
      ora: inizio == null ? '' : _ora(inizio),
      colore: materiale.coloreTodo(todo, Brightness.light),
      coloreScuro: materiale.coloreTodo(todo, Brightness.dark),
      tuttoIlGiorno: inizio == null,
      fatto: materiale.todoFatto(todo, giorno),
      emoji: materiale.emoji(todo.categoryIds),
      inCorso: oggi &&
          inizio != null &&
          fine != null &&
          _minutiAdesso(materiale.adesso) >= inizio &&
          _minutiAdesso(materiale.adesso) < fine,
    );
    if (inizio == null) {
      senzaOraTodo.add(todo);
      senzaOra.add(riga);
    } else {
      conOra.add((minuti: inizio, indice: indice, riga: riga));
    }
    indice++;
  }

  conOra.sort((a, b) {
    final perOra = a.minuti.compareTo(b.minuti);
    return perOra != 0 ? perOra : a.indice.compareTo(b.indice);
  });
  senzaOraTodo.sort(confrontaTodo);

  final righe = [
    for (final voce in conOra) voce.riga,
    ...senzaOra,
  ];

  final fatti = [
    for (final elemento in todo)
      if (materiale.todoFatto(elemento, giorno)) elemento,
  ].length;

  return WidgetGiorno(
    data: giorno,
    etichetta: materiale.etichettaDelGiorno(giorno),
    stato: statoDelGiorno(
      eventi: eventi.length,
      todo: todo.length,
      todoFatti: fatti,
    ),
    righe: righe.length > righeNelPacchetto
        ? righe.sublist(0, righeNelPacchetto)
        : righe,
    eventi: eventi.length,
    todo: todo.length,
    todoFatti: fatti,
  );
}

/// Il pacchetto intero: **oggi più i giorni dopo**, uno per chiave.
///
/// Otto giorni perché è quello che rende il widget giusto anche se l'app non si
/// apre per una settimana: il Kotlin sceglie la chiave del giorno che serve e non
/// deve chiedere niente a Flutter (che, con l'app chiusa, non c'è).
Map<DateTime, WidgetGiorno> pacchettoDelWidget({
  required DateTime oggi,
  required MaterialeDelWidget materiale,
  int giorni = giorniNelPacchetto,
}) {
  final primo = _soloGiorno(oggi);
  return {
    for (var scarto = 0; scarto < giorni; scarto++)
      DateTime(primo.year, primo.month, primo.day + scarto): giornoDelWidget(
        DateTime(primo.year, primo.month, primo.day + scarto),
        materiale,
      ),
  };
}

/// I minuti dalla mezzanotte di un istante: è la forma in cui il giorno misura
/// gli orari (e in cui li salvano i todo).
int _minutiAdesso(DateTime quando) => quando.hour * 60 + quando.minute;

DateTime _soloGiorno(DateTime quando) =>
    DateTime(quando.year, quando.month, quando.day);

bool _stessoGiorno(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// `14:30` (o `09:05`).
///
/// Tre righe scritte qui invece di importare `ui/shared/formatters.dart`, per una
/// ragione di **strati**: la logica (`features/`) non importa la UI (è la regola
/// che tiene il progetto condivisibile con la shell desktop), e questo file è
/// logica. La forma dell'ora qui non è una scelta di stile della schermata: è
/// parte del contratto con il Kotlin, che la stampa così com'è. Se un giorno
/// servisse un terzo posto, si sposta `formatTime` in `core/` e si tolgono tutte.
String _ora(int minuti) => '${(minuti ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuti % 60).toString().padLeft(2, '0')}';

String _oraDi(DateTime quando) => _ora(_minutiAdesso(quando));
