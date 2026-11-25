import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../../features/notifications/notification_settings_controller.dart';
import '../../theme/design_tokens.dart';
import '../shared/formatters.dart';
import '../shared/scelta_sheet.dart';

/// Le **scelte** della sezione notifiche: fogli dal basso con dentro un elenco.
///
/// Stanno in un file loro perché sono la parte lunga e senza stato della
/// pagina (le righe restano in `notifications_rows.dart`), e perché la forma è
/// **una sola** — «quale di queste?» — con l'elenco che cambia: il suono, il
/// contenuto sulla schermata di blocco, l'anticipo, le ore silenziose.
///
/// Perché un foglio e non una pagina: sono scelte da due tocchi, e una pagina
/// per ognuna vorrebbe dire quattro pagine che si aprono e si chiudono.

/// Una scelta fra poche opzioni, con la spunta su quella attiva.
Future<void> mostraScelta<T>(
  BuildContext context, {
  required String titolo,
  required List<({T valore, String etichetta, String? nota})> opzioni,
  required T attuale,
  required ValueChanged<T> onScelta,
}) {
  return showActaSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints:
        BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
    builder: (context) => SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: opzioni.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.l,
                AppSpacing.l,
                AppSpacing.s,
              ),
              child:
                  Text(titolo, style: Theme.of(context).textTheme.titleSmall),
            );
          }
          final opzione = opzioni[index - 1];
          return ListTile(
            key: ValueKey('scelta-${opzione.valore}'),
            title: Text(opzione.etichetta),
            subtitle: opzione.nota == null ? null : Text(opzione.nota!),
            trailing:
                opzione.valore == attuale ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.pop(context);
              onScelta(opzione.valore);
            },
          );
        },
      ),
    ),
  );
}

/// Il **suono** degli avvisi: le tre suonate incluse, quella di sistema, o
/// nessuno.
///
/// È una proprietà del **canale** di Android, non della singola notifica (dopo
/// la creazione non si cambia più): cambiare il tono qui vuol dire usare un
/// canale nuovo, che il sink crea alla prima pianificazione. Il canale vecchio
/// resta nell'elenco di Android — limite dichiarato nella specifica.
Future<void> mostraSceltaSuono(
  BuildContext context,
  NotificationSettingsController notifiche,
) {
  return mostraScelta<String>(
    context,
    titolo: 'Suono degli avvisi',
    attuale: notifiche.suono,
    opzioni: const [
      (
        valore: NotificationSettingsController.suonoSistema,
        etichetta: 'Suono di notifica',
        nota: 'Quello che il telefono usa per le notifiche',
      ),
      (
        valore: NotificationSettingsController.suonoSveglia,
        etichetta: 'Suono della sveglia',
        nota: 'Il suono della sveglia del telefono',
      ),
      (
        valore: NotificationSettingsController.suonoSuoneria,
        etichetta: 'Suoneria',
        nota: 'La suoneria del telefono',
      ),
      (
        valore: NotificationSettingsController.suonoNessuno,
        etichetta: 'Nessuno',
        nota: 'Gli avvisi arrivano lo stesso, in silenzio',
      ),
    ],
    onScelta: notifiche.setSuono,
  );
}

/// Il contenuto sulla **schermata di blocco**: quanto si legge di un avviso a
/// telefono bloccato.
Future<void> mostraSceltaBlocco(
  BuildContext context,
  NotificationSettingsController notifiche,
) {
  return mostraScelta<String>(
    context,
    titolo: 'Sulla schermata di blocco',
    attuale: notifiche.blocco,
    opzioni: const [
      (
        valore: NotificationSettingsController.bloccoPubblico,
        etichetta: 'Si legge tutto',
        nota: 'Titolo e ora, anche a blocco protetto',
      ),
      (
        valore: NotificationSettingsController.bloccoPrivato,
        etichetta: 'Privato',
        nota: 'Nascosto se il blocco è protetto da PIN o impronta',
      ),
      (
        valore: NotificationSettingsController.bloccoSegreto,
        etichetta: 'Segreto',
        nota: 'Non si legge mai a telefono bloccato',
      ),
    ],
    onScelta: notifiche.setBlocco,
  );
}

/// L'**anticipo** con cui avvisare: una manciata di valori sensati, non un
/// numero da digitare. Lo zero è «all'ora esatta».
Future<void> mostraSceltaAnticipo(
  BuildContext context, {
  required String titolo,
  required int attuale,
  required ValueChanged<int> onScelta,
}) {
  return mostraScelta<int>(
    context,
    titolo: titolo,
    attuale: attuale,
    opzioni: const [
      (valore: 0, etichetta: 'All\'ora esatta', nota: null),
      (valore: 5, etichetta: '5 minuti prima', nota: null),
      (valore: 10, etichetta: '10 minuti prima', nota: null),
      (valore: 15, etichetta: '15 minuti prima', nota: null),
      (valore: 30, etichetta: '30 minuti prima', nota: null),
      (valore: 60, etichetta: '1 ora prima', nota: null),
      (valore: 120, etichetta: '2 ore prima', nota: null),
      (valore: 1440, etichetta: 'Il giorno prima', nota: null),
    ],
    onScelta: onScelta,
  );
}

/// L'**ora** da un orologio: torna i minuti dalla mezzanotte, o `null` se il
/// foglio si chiude senza scegliere.
Future<int?> chiediOra(
  BuildContext context, {
  required String titolo,
  required int attuale,
}) async {
  final scelta = await showTimePicker(
    context: context,
    helpText: titolo,
    initialTime: TimeOfDay(hour: attuale ~/ 60, minute: attuale % 60),
  );
  return scelta == null ? null : scelta.hour * 60 + scelta.minute;
}

/// Le **ore silenziose**: da, a, o nessuna.
///
/// Un intervallo che scavalca la mezzanotte (22:00 → 07:00) è il caso normale,
/// quindi le due estremità si scelgono separatamente: chiedere «dalle 22 alle
/// 7» in un unico intervallo vorrebbe dire spiegare che il primo numero è più
/// grande del secondo.
Future<void> mostraFoglioSilenzio(
  BuildContext context,
  NotificationSettingsController notifiche,
) async {
  final azione = await mostraSceltaAzione(
    context,
    titolo: 'Ore silenziose',
    voci: [
      (
        valore: 'da',
        etichetta: 'Da',
        nota: formatMinutes(notifiche.silenzioDa),
      ),
      (valore: 'a', etichetta: 'A', nota: formatMinutes(notifiche.silenzioA)),
      (
        valore: 'nessuna',
        etichetta: 'Nessuna',
        nota: notifiche.quietHours == null
            ? 'Già così'
            : 'Gli avvisi suonano sempre',
      ),
    ],
  );
  if (azione == null || azione == 'nessuna') {
    if (azione == 'nessuna') {
      notifiche.setSilenzio(da: 0, a: 0);
    }
    return;
  }
  if (!context.mounted) return;

  final ora = await chiediOra(
    context,
    titolo: azione == 'da' ? 'Da quando' : 'Fino a quando',
    attuale: azione == 'da' ? notifiche.silenzioDa : notifiche.silenzioA,
  );
  if (ora == null) return;
  notifiche.setSilenzio(
    da: azione == 'da' ? ora : notifiche.silenzioDa,
    a: azione == 'a' ? ora : notifiche.silenzioA,
  );
}

/// Un foglio di sole voci da toccare, senza spunta: si sceglie e si chiude.
/// La forma condivisa sta in `ui/shared/scelta_sheet.dart` (la usa anche la riga
/// «Todo nel calendario»): qui c'era una copia, ed era la seconda.
