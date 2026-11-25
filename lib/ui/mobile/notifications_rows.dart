import 'package:flutter/material.dart';

import '../../features/notifications/notification_settings_controller.dart';
import '../shared/formatters.dart';
import 'notifications_sheets.dart';

/// Le **righe** della sezione notifiche: un interruttore per tipo, una scelta che
/// apre un foglio, un'ora da cambiare.
///
/// Stanno in un file loro per il tetto delle 300 righe — la sezione con dentro
/// anche il permesso e la puntualità ci arrivava — e perché sono la parte che non
/// decide niente: mostrano uno stato e chiamano un callback.

/// Una riga di tipo: l'interruttore e, sotto, **quando** arriva quell'avviso.
///
/// La nota non è decorazione: «Scadenze dei todo» da solo non dice a che ora, e
/// l'ora l'utente la vuole sapere senza aprire niente. Lo stesso testo è quello
/// che si cambia in Esperto, dove le ore hanno le loro righe.
class TipoAvviso extends StatelessWidget {
  const TipoAvviso({
    super.key,
    required this.chiave,
    required this.titolo,
    required this.nota,
    required this.valore,
    required this.onCambia,
  });

  final String chiave;
  final String titolo;
  final String nota;
  final bool valore;
  final ValueChanged<bool> onCambia;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: ValueKey(chiave),
      contentPadding: EdgeInsets.zero,
      value: valore,
      onChanged: onCambia,
      title: Text(titolo),
      subtitle: Text(nota),
    );
  }
}

/// Una riga che dice com'è impostata una cosa e apre il foglio per cambiarla.
class RigaScelta extends StatelessWidget {
  const RigaScelta({
    super.key,
    required this.chiave,
    required this.titolo,
    required this.nota,
    required this.onTocca,
    this.icona,
    this.avviso = false,
    this.freccia = true,
  });

  final String chiave;
  final String titolo;
  final String nota;
  final VoidCallback onTocca;
  final IconData? icona;

  /// Vero per le righe che dicono di un **guaio** (il permesso negato): l'icona
  /// e il testo devono saltare all'occhio anche a chi non stava cercando niente.
  final bool avviso;

  /// Vero (il default) per le righe che **aprono** qualcosa. Falso per le azioni
  /// che succedono e basta (la prova dell'avviso): una freccia promette una
  /// schermata che non arriva.
  final bool freccia;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: ValueKey(chiave),
      contentPadding: EdgeInsets.zero,
      leading: icona == null
          ? null
          : Icon(icona, color: avviso ? scheme.error : null),
      title: Text(
        titolo,
        style: avviso ? TextStyle(color: scheme.error) : null,
      ),
      subtitle: Text(nota),
      trailing: freccia ? const Icon(Icons.chevron_right) : null,
      onTap: onTocca,
    );
  }
}

/// Una riga con **un'ora** da cambiare: si apre l'orologio di sistema.
class RigaOra extends StatelessWidget {
  const RigaOra({
    super.key,
    required this.chiave,
    required this.titolo,
    required this.minuti,
    required this.onCambia,
  });

  final String chiave;
  final String titolo;
  final int minuti;
  final ValueChanged<int> onCambia;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(chiave),
      contentPadding: EdgeInsets.zero,
      title: Text(titolo),
      subtitle: Text(formatMinutes(minuti)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final ora = await chiediOra(context, titolo: titolo, attuale: minuti);
        if (ora != null) onCambia(ora);
      },
    );
  }
}

/// Una riga che **non si tocca**: dice com'è una cosa che decide il sistema.
class RigaInformativa extends StatelessWidget {
  const RigaInformativa({
    super.key,
    required this.chiave,
    required this.titolo,
    required this.nota,
    required this.icona,
  });

  final String chiave;
  final String titolo;
  final String nota;
  final IconData icona;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey(chiave),
      contentPadding: EdgeInsets.zero,
      leading: Icon(icona),
      title: Text(titolo),
      subtitle: Text(nota, style: theme.textTheme.bodySmall),
    );
  }
}

/// «15 minuti prima», «1 ora prima», «il giorno prima», «all'ora esatta».
///
/// Sta qui e non nella sezione perché lo mostrano **due** righe (l'anticipo e il
/// sottotitolo di un tipo di avviso): due copie divergerebbero al primo ritocco.
String durataNotifica(int minuti) {
  if (minuti <= 0) return 'all\'ora esatta';
  if (minuti < 60) return '$minuti minuti prima';
  if (minuti == 60) return '1 ora prima';
  if (minuti < 24 * 60) return '${minuti ~/ 60} ore prima';
  return minuti == 24 * 60
      ? 'il giorno prima'
      : '${minuti ~/ 1440} giorni prima';
}

/// Il nome del suono scelto, come si legge.
String nomeSuonoNotifica(String suono) => switch (suono) {
      NotificationSettingsController.suonoSistema => 'Suono di notifica',
      NotificationSettingsController.suonoSveglia => 'Suono della sveglia',
      NotificationSettingsController.suonoSuoneria => 'Suoneria',
      _ => 'Nessuno',
    };

/// Quanto si legge di un avviso a telefono bloccato.
String nomeBloccoNotifica(String blocco) => switch (blocco) {
      NotificationSettingsController.bloccoPubblico => 'Si legge tutto',
      NotificationSettingsController.bloccoSegreto => 'Segreto',
      _ => 'Privato',
    };
