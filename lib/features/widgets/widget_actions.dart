/// La spunta fatta **dal widget**: il pezzo che gira anche con l'app chiusa.
///
/// Due cose in un file solo, e sono due cose diverse:
///
/// * [conLaSpunta] — pura, senza database: la giornata pubblicata con la spunta
///   cambiata, i conteggi aggiustati e lo stato ricalcolato. Si prova senza
///   telefono;
/// * [callbackDelWidget] — l'**entrata** che il plugin chiama quando si tocca la
///   spunta. È l'unico punto dell'app che viene eseguito in un processo suo,
///   avviato dal sistema, senza interfaccia e senza nessuno che guardi: qui non
///   si dà niente per scontato e si apre il database da zero. Per questo il file
///   importa il binding di Flutter (`package:flutter/widgets.dart`, **non**
///   Material): la logica resta senza widget, l'entrata no.
library;

import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

import '../../core/database/database_service.dart';
import '../todos/todo_provider.dart';
import '../todos/todo_recurrence.dart';
import 'domain/widget_payload.dart';
import 'home_widget_bridge.dart';
import 'widget_bridge.dart';
import 'widget_contract.dart';

/// La giornata con la spunta di un todo messa o tolta.
///
/// Non si rilegge niente dal database — colori, emoji, orari e righe restano
/// quelli pubblicati, perché una spunta non li cambia — e non serve avere in mano
/// palette e categorie in un processo che parla solo col widget. Cambiano le tre
/// cose che una spunta cambia davvero: la riga, i conteggi e lo stato.
///
/// Limite dichiarato: i conteggi si aggiustano di uno rispetto a quelli
/// pubblicati. Se nel frattempo l'app ha cambiato la giornata (un todo aggiunto,
/// un evento spostato), il conteggio resta indietro di quel tanto fino alla
/// prossima apertura dell'app, che riscrive tutto il pacchetto.
WidgetGiorno conLaSpunta(
  WidgetGiorno giorno, {
  required String id,
  required bool fatto,
}) {
  final righe = <WidgetRow>[];

  for (final riga in giorno.righe) {
    righe.add(
      riga.isTodo && riga.id == id ? riga.copyWith(fatto: fatto) : riga,
    );
  }

  // La riga può anche non essere fra quelle pubblicate (la giornata è più lunga
  // del pacchetto): la spunta è cambiata lo stesso, e il conteggio la segue.
  final fatti = (giorno.todoFatti + (fatto ? 1 : -1)).clamp(0, giorno.todo);

  return WidgetGiorno(
    data: giorno.data,
    etichetta: giorno.etichetta,
    stato: statoDelGiorno(
      eventi: giorno.eventi,
      todo: giorno.todo,
      todoFatti: fatti,
    ),
    righe: righe,
    eventi: giorno.eventi,
    todo: giorno.todo,
    todoFatti: fatti,
  );
}

/// Spunta — o toglie la spunta — a un todo partendo dal widget, e ridisegna.
///
/// La regola è **quella dell'app**, non una copia: `toggleForDay` (un ricorrente
/// segna l'occorrenza di quel giorno, uno singolo cambia stato), quindi il tocco
/// sul widget fa esattamente quello che farebbe un tocco nell'app — compreso il
/// limite: **un'occorrenza ricorrente non si toglie** (l'app non lo sa fare).
///
/// Torna `true` se il todo esiste ed è stato scritto.
Future<bool> spuntaDalWidget({
  required DatabaseService db,
  required WidgetBridge bridge,
  required String id,
  required DateTime giorno,
}) async {
  final todo = TodoProvider(db);
  final indice = todo.todos.indexWhere((elemento) => elemento.id == id);
  if (indice < 0) return false;

  final elemento = todo.todos[indice];
  todo.toggleForDay(elemento, giorno);

  // Il todo si rilegge **dopo** la scrittura: per uno singolo `toggleForDay` ha
  // sostituito la riga nella lista, e l'oggetto di prima racconta ancora lo stato
  // vecchio (è il difetto che questo test ha trovato). Per un ricorrente lo stato
  // sta nell'occorrenza, quindi la rilettura non cambia niente.
  final aggiornato = todo.todos.firstWhere(
    (riga) => riga.id == id,
    orElse: () => elemento,
  );
  final fatto = todo.isDoneOn(aggiornato, giorno);

  final pubblicato = await bridge.leggiGiorno(giorno);
  if (pubblicato == null) return true;

  await bridge.aggiornaGiorno(conLaSpunta(pubblicato, id: id, fatto: fatto));
  return true;
}

/// L'entrata che il plugin chiama toccando la spunta di un todo.
///
/// `@pragma('vm:entry-point')` non è decorazione: senza, in release il
/// compilatore toglie questa funzione (nessuno la chiama **da dentro** l'app —
/// la chiama il sistema) e il tocco non fa più niente, in un modo che non si vede
/// finché non si prova sul telefono.
@pragma('vm:entry-point')
Future<void> callbackDelWidget(Uri? uri) async {
  // Due righe di log, e non è pedanteria: questo percorso gira **senza
  // interfaccia**, in un processo che può esistere solo per lui, e senza una
  // traccia nel log non si sa se è arrivato o dove si è fermato (è esattamente il
  // modo in cui il 24/09 si è scoperto che l'aggiornamento dei widget falliva con
  // `PlatformException(-3)`).
  debugPrint('widget: tocco ricevuto ($uri)');

  final tocca = leggiToccaDelWidget(uri);
  if (tocca == null || tocca.azione != 'spunta') {
    debugPrint('widget: tocco ignorato (non è una spunta nostra)');
    return;
  }
  final id = tocca.id;
  final giorno = tocca.giorno;
  if (tocca.tipo != tipoTodo || id == null || giorno == null) {
    debugPrint('widget: tocco ignorato (manca il todo o il giorno)');
    return;
  }

  // In un isolate di sfondo i plugin non sono registrati da soli, e il percorso
  // del database lo chiede a `path_provider`.
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final db = DatabaseService();
  await db.init();
  try {
    final scritto = await spuntaDalWidget(
      db: db,
      bridge: const HomeWidgetBridge(),
      id: id,
      giorno: giorno,
    );
    debugPrint(
      'widget: spunta di $id (${dataIso(giorno)}) '
      '${scritto ? 'scritta' : 'saltata: il todo non c\'è'}',
    );
  } finally {
    db.close();
  }
}
