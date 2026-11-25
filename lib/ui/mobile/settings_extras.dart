import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/categories/category_controller.dart';
import '../../features/notifications/notification_settings_controller.dart';
import '../../features/settings/app_settings_controller.dart';
import '../shared/opzioni_avanzate.dart';
import '../shared/scelta_sheet.dart';
import 'categories_page.dart';
import 'notifications_page.dart';

/// Le tre righe «diverse» della pagina delle impostazioni.
///
/// Stanno qui e non in `settings_page.dart` per il tetto delle 300 righe
/// (`test/architecture_test.dart`), e perché hanno in comune una cosa sola: si
/// leggono **da sole** quello che mostrano (il conteggio delle categorie, gli
/// avvisi accesi, l'Esperto) invece di riceverlo dalla pagina. Così la pagina non
/// si ricostruisce quando cambia una categoria o un tipo di avviso.

/// La riga **«Categorie»**, col conteggio.
///
/// Dopo le categorie di default ce ne sono **otto** appena si apre l'app, e il
/// numero lo dice: senza, la riga sembrava il posto dove andare a crearle tutte a
/// mano — che è esattamente il lavoro che il seme toglie di mezzo.
class CategorieRow extends StatelessWidget {
  const CategorieRow({super.key});

  @override
  Widget build(BuildContext context) {
    final quante = context.watch<CategoryController>().all.length;

    return ListTile(
      key: const ValueKey('impostazioni-categorie'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.label_outline),
      title: const Text('Categorie'),
      subtitle: Text(
        quante == 0
            ? 'Le etichette di eventi e To do'
            : quante == 1
                ? '1 etichetta'
                : '$quante etichette',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => apriPagina(context, const CategoriesPage()),
    );
  }
}

/// La riga **«Notifiche»**: dice se gli avvisi sono accesi e apre la pagina.
///
/// Il sottotitolo è **corto** di proposito: chi ha spento due tipi lo vede da qui
/// senza aprire niente, e chi non ha mai toccato niente legge «Accesi» e basta.
/// La sezione lunga che c'era — quattro tipi con le loro ore, più le manopole —
/// è quella che rendeva illeggibile la pagina a chi non stava cercando niente.
class NotificheRow extends StatelessWidget {
  const NotificheRow({super.key});

  @override
  Widget build(BuildContext context) {
    final notifiche = context.watch<NotificationSettingsController>();
    final accesi = [
      notifiche.evento,
      notifiche.todo,
      notifiche.tuttoIlGiorno,
      notifiche.riepilogo,
    ].where((acceso) => acceso).length;

    return ListTile(
      key: const ValueKey('impostazioni-notifiche'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.notifications_outlined),
      title: const Text('Notifiche'),
      subtitle: Text(
        !notifiche.attive
            ? 'Spenti: non arriva niente'
            : accesi == 4
                ? 'Accesi · 4 tipi'
                : 'Accesi · $accesi di 4',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => apriPagina(context, const NotificationsPage()),
    );
  }
}

/// Preferenze secondarie della pagina Impostazioni.
class AvanzateSection extends StatelessWidget {
  const AvanzateSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();

    return OpzioniAvanzate(
      key: const ValueKey('impostazioni-opzioni-avanzate'),
      nota: 'Personalizza animazioni e impegni scaduti',
      children: [
        SwitchListTile(
          key: const ValueKey('impostazioni-animazioni'),
          contentPadding: EdgeInsets.zero,
          value: settings.animationsEnabled,
          onChanged: settings.setAnimationsEnabled,
          title: const Text('Animazioni'),
          subtitle:
              const Text('Il «riduci animazioni» di sistema vince comunque'),
        ),
        ListTile(
          key: const ValueKey('impostazioni-scaduti'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostra gli scaduti per'),
          subtitle: Text('${settings.overdueWindowDays} giorni'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _scegliFinestra(context, settings),
        ),
      ],
    );
  }

  /// Quanto indietro guarda il foglio degli scaduti: **quattro scelte**, non un
  /// numero da digitare. Nessuno sa a memoria quante scadenze vecchie vuole
  /// vedere, e 30 giorni va bene a chi non ci pensa.
  static Future<void> _scegliFinestra(
    BuildContext context,
    AppSettingsController settings,
  ) async {
    const voci = [
      (7, 'Solo la settimana scorsa'),
      (15, 'Le ultime due settimane'),
      (30, 'L\'ultimo mese (il valore di partenza)'),
      (90, 'Tre mesi: la coda è lunga'),
    ];

    final scelto = await mostraSceltaAzione(
      context,
      titolo: 'Finestra degli scaduti',
      voci: [
        for (final (giorni, nota) in voci)
          (valore: '$giorni', etichetta: '$giorni giorni', nota: nota),
      ],
    );
    if (scelto == null) return;
    settings.setOverdueWindowDays(int.parse(scelto));
  }
}

/// Apre una pagina sopra le impostazioni: la stessa strada per tutte le righe
/// che portano altrove (categorie, priorità, copie, avvisi, sync).
///
/// Una funzione e non un metodo della pagina: le righe che aprono qualcosa stanno
/// in questo file e in `settings_page.dart`, e due copie della stessa `push`
/// divergerebbero alla prima aggiunta.
Future<void> apriPagina(BuildContext context, Widget pagina) => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => pagina),
    );
