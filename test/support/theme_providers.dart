import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'fake_notification_sink.dart';

import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/categories/category_controller.dart';
import 'package:planner/features/filters/filtro_condiviso_controller.dart';
import 'package:planner/features/notifications/notification_settings_controller.dart';
import 'package:planner/features/notifications/notification_sink.dart';
import 'package:planner/features/palette/palette_controller.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/todos/todo_filter_controller.dart';
import 'package:planner/features/todos/todo_selection.dart';

/// I provider che servono a **qualsiasi** schermata che disegna un colore, una
/// etichetta o i filtri dei todo.
///
/// Da quando il tema nasce dalla palette attiva, una pagina che mostra un evento
/// o un todo legge preferenze e palette; da quando esistono le categorie e i
/// filtri, la scheda Todo legge anche quelli; da quando c'e' il filtro condiviso
/// (#92), calendario e agenda leggono anche quello; da quando c'e' la selezione
/// multipla (#90), chi mostra i todo legge anche **chi e' selezionato** — e il
/// guscio la legge per il tasto indietro. Senza uno di questi provider il test
/// fallisce con `ProviderNotFoundException`, che è un errore del test, non
/// dell'app: averli in un posto solo evita di dimenticarli nel prossimo.
List<SingleChildWidget> themeProviders(DatabaseService db) {
  return [
    ChangeNotifierProvider.value(
      value: AppSettingsController(db.settings)..load(),
    ),
    ChangeNotifierProvider.value(
      value: PaletteController(db)
        ..load()
        ..allineaPresets(),
    ),
    ChangeNotifierProvider.value(value: CategoryController(db)),
    ChangeNotifierProvider.value(
      value: TodoFilterController(db.settings)..load(),
    ),
    // Il filtro condiviso: lo legge il calendario (le tre viste) e l'agenda.
    ChangeNotifierProvider.value(
      value: FiltroCondivisoController(db.settings)..load(),
    ),
    // Le preferenze delle notifiche: le legge la sezione in Impostazioni (e, dal
    // prossimo passo, il pianificatore dei promemoria).
    ChangeNotifierProvider.value(
      value: NotificationSettingsController(db.settings)..load(),
    ),
    // Il sink finto: la sezione gli chiede il permesso e lo stato del sistema, e
    // senza questo provider montare le Impostazioni fallisce.
    Provider<NotificationSink>.value(value: FakeNotificationSink()),
    ChangeNotifierProvider(create: (_) => SelezioneDeiTodo()),
  ];
}
