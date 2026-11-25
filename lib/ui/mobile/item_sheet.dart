import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/events/domain/event.dart';
import '../../features/notes/note_provider.dart';
import '../../features/todos/domain/todo.dart';
import '../shared/form_sheet.dart';
import 'item_form.dart';
import 'item_type.dart';

// Chi apre il form ha bisogno anche del tipo: l'export evita di importare due
// file per una sola cosa (e non crea cicli: `item_type` non dipende da nulla).
export 'item_type.dart';

/// Vero finche' un form non si e' aperto **una volta** in questa sessione.
///
/// La prima apertura e' l'unica che paga la prima rasterizzazione del contenuto
/// del form: misurato sul telefono con l'agenda di prova, 11,8 ms di build +
/// **22,1 ms di raster** contro 7-12 + 4 delle aperture successive. Con
/// un'animazione quella spesa si vede — il foglio si ferma mentre sale — e per
/// questo la prima apertura non si anima: il foglio compare gia' completo, con
/// un fotogramma di attesa al posto di uno scatto. E' il compromesso scelto:
/// fermarsi un istante, non tremare.
bool _primaApertura = true;

/// Apre il form di creazione/modifica: **un solo foglio** per eventi e todo.
///
/// Con `event` o `todo` valorizzati si sta modificando (e il selettore
/// sparisce: cambiare tipo a un elemento esistente sarebbe una conversione, non
/// una modifica). In creazione il selettore sta in cima e cambiarlo **non perde
/// niente**: i campi condivisi li tiene il form, i due gruppi specifici solo si
/// scambiano.
Future<void> showItemForm(
  BuildContext context, {
  required ItemType type,
  required DateTime day,
  Event? event,
  Todo? todo,
  String? initialTitle,
  String? initialNote,
}) {
  final prima = _primaApertura;
  _primaApertura = false;

  NoteProvider? noteProvider;
  try {
    noteProvider = context.read<NoteProvider>();
  } on ProviderNotFoundException {
    noteProvider = null;
  }

  return showFormSheet(
    context,
    (_) => ItemForm(
      type: type,
      day: day,
      event: event,
      todo: todo,
      noteProvider: noteProvider,
      initialTitle: initialTitle,
      initialNote: initialNote,
    ),
    durataApertura: prima ? Duration.zero : null,
    isDismissible: event != null || todo != null,
  );
}
