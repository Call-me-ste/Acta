import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../features/filters/filtro_condiviso.dart';
import '../../features/filters/filtro_condiviso_controller.dart';

/// Il filtro condiviso **attivo**, o «nessun vincolo» se nessuno l'ha montato.
///
/// Perche' un ripiego invece di pretendere il provider: mezza dozzina di test
/// montano una pagina sola (il calendario, un foglio) senza l'intera catena di
/// `main()`, ed e' una cosa che deve restare possibile — e' cosi' che si prova
/// una vista senza portarsi dietro l'app. Il ripiego e' **il default della
/// classe** (`FiltroCondiviso()`), cioe' esattamente quello che il calendario fa
/// da sempre: chi guarda senza filtri non vede cambiare niente. La stessa scelta
/// di `TabActive.of` ("manca chi lo dice? si comporta come sempre").
///
/// Chi *scrive* il filtro deve invece passare dal controller, che e' anche
/// l'unico a ricordarlo fra un avvio e l'altro.
FiltroCondiviso filtroAttivo(BuildContext context) =>
    context.watch<FiltroCondivisoController?>()?.filtro ??
    const FiltroCondiviso();

/// Come [filtroAttivo], ma **senza iscriversi**: per chi legge il filtro fuori da
/// un `build` (un callback di fine fotogramma, un gesto).
FiltroCondiviso filtroAttuale(BuildContext context) =>
    context.read<FiltroCondivisoController?>()?.filtro ??
    const FiltroCondiviso();
