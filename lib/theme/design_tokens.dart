import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Raggi, spazi e tempi in un posto solo.
///
/// Nascono da una lettura delle linee guida One UI (che usano **18** per i
/// bottoni e i raggi grandi per i "focus block"), dalla scala di Material 3
/// **Expressive** (16 "large", 20 "largeIncreased") e dal default iCal/Apple per
/// le pillole. Il punto non è il valore: è che sia **lo stesso** in tutta l'app.
/// Valori sparsi sono il motivo per cui due schermate della stessa app sembrano
/// di due app diverse.
class AppRadius {
  const AppRadius._();

  /// Barre e elementi sottili (3-4 px): un raggio più grande di così non si
  /// vedrebbe nemmeno.
  static const double bar = 4;

  /// Elementi piccoli: chip, pillole di testo, campi compatti.
  static const double chip = 8;

  /// Raggio medio degli input.
  static const double small = 12;

  /// Superfici: card, celle, righe di lista (M3 Expressive "large").
  static const double card = 16;

  /// Bottoni contenuti (One UI) e superfici grandi (M3 "largeIncreased").
  static const double button = 18;
  static const double large = 20;

  /// Fogli e dialoghi.
  static const double sheet = 28;

  /// La pillola: un semicerchio, qualunque sia l'altezza. Si usa al posto di un
  /// raggio fisso perché non deve cambiare se il contenuto cresce. Il tipo è
  /// `OutlinedBorder` (non `ShapeBorder`) perché è quello che chiedono i widget
  /// Material: `StadiumBorder` lo implementa.
  static const OutlinedBorder pill = StadiumBorder();

  /// Pillola come raggio, per chi ha bisogno di un double (es. AnimatedAlign).
  static BorderRadius pillRadius(double height) =>
      BorderRadius.circular(height / 2);
}

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;

  /// Margine laterale minimo delle schermate (One UI: almeno 24 dp sui lati).
  static const double page = 20;

  /// Altezza minima di un bersaglio toccabile (linee guida di accessibilità).
  static const double touchTarget = 48;

  /// La colonna degli orari, uguale in settimana e giorno: 56 è un multiplo di
  /// 8 e regge "00:00" anche a testo 1,3 senza tagliarlo.
  static const double hourGutter = 56;

  /// Corsa aggiuntiva per portare l'ultima riga sopra i pulsanti del calendario.
  static const double calendarActionsClearance = 2 * (touchTarget + s) + l;

  /// La misura delle icone **dentro** una riga di campo: uguale dappertutto,
  /// perché è da lì che si calcola l'indentatura del testo della riga.
  static const double icon = 20;

  /// Icona piccola: azioni di testo e chevron. Due misure di icona e non una,
  /// perché il chevron accanto a una riga da 20 la sbilancierebbe.
  static const double iconSmall = 18;

  /// Dove comincia il testo di una riga con icona: icona più uno spazio `m`.
  /// Derivata, non copiata — un `left: 56` scritto a mano è esattamente quello
  /// che restava disallineato quando l'icona cambiava misura.
  static const double rowText = icon + m;

  /// Altezza di una barra con comandi a riga singola e testo scalabile.
  static double labelBarHeight(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    final size = style?.fontSize;
    if (size == null) return touchTarget;
    final scaled = MediaQuery.textScalerOf(context).scale(size);
    return math.max(touchTarget, scaled * (style?.height ?? 1.2) + 2 * s);
  }
}

/// Le misure di testo **sotto** il più piccolo del `textTheme`.
///
/// Servono dove il `labelSmall` (11) non ci sta: la cella del mese e i blocchi
/// della settimana. Stanno qui perché la regola è "solo `textTheme`": se una
/// misura deve esistere comunque, vive fra i token e non come numero sparso nel
/// widget.
class AppType {
  const AppType._();

  /// Titolo in un blocco della settimana, conteggio nel badge del mese.
  static const double micro = 9.5;

  /// Orario in un blocco basso, «+N» nella cella del mese.
  static const double nano = 8;
}

class AppMotion {
  const AppMotion._();

  /// Le durate: **un posto solo** per tutta l'app.
  ///
  /// Alzate su richiesta dell'utente («preferisco che le animazioni siano
  /// leggermente piu' lente, per evitare gli scatti»). Il motivo per cui
  /// funziona: il costo di un fotogramma pesante non cambia, ma un movimento piu'
  /// lungo **lo distribuisce su piu' fotogrammi**, e un fotogramma saltato si
  /// nota molto meno. Material indica 200-500 ms per le transizioni grandi: siamo
  /// dentro, dalla parte morbida.
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 360);

  static const Duration sheetEntrance = Duration(milliseconds: 360);
  static const Duration sheetExit = Duration(milliseconds: 260);
  static const Duration menuEntrance = Duration(milliseconds: 290);
  static const Duration menuExit = Duration(milliseconds: 210);
  static const Duration controlSelection = Duration(milliseconds: 360);

  /// La pausa prima dell'autosave di una nota: l'utente sta scrivendo, non
  /// aspetta una transizione.
  static const Duration autosave = Duration(milliseconds: 700);

  /// La pausa che raggruppa le battute in **un** passo di cronologia: annullare
  /// una parola, non una lettera.
  static const Duration history = Duration(milliseconds: 600);
  static const Curve curve = Curves.easeOutCubic;

  /// Il "rimbalzino" discreto delle interfacce Apple: un overshoot breve, non
  /// una molla che oscilla (280-360 ms con bounce 0.18-0.28 è il range che le
  /// linee guida indicano per i controlli). **Curva dell'SDK**, non fisica
  /// custom: in v2 la fisica di scroll scritta a mano è stata uno dei difetti da
  /// smontare.
  ///
  /// 320 ms: la pallina attraversa tutta la larghezza, quindi il rimbalzino si
  /// vede ancora, ma la pillola risponde senza l'attesa che si sentiva a 440 ms.
  static const Duration springDuration = Duration(milliseconds: 320);
  static const Curve spring = Cubic(0.34, 1.42, 0.64, 1);

  static const Duration viewSwitch = Duration(milliseconds: 420);
  static const Duration viewRetarget = Duration(milliseconds: 290);
  static const Curve viewCurve = Cubic(0.32, 0.06, 0.24, 1);
  static const Curve viewRetargetCurve = Cubic(0.22, 0.50, 0.32, 1);
  static const Curve controlCurve = Cubic(0.22, 0.25, 0, 1);

  /// La durata effettiva: con le animazioni spente (o col "riduci animazioni" di
  /// sistema) il movimento è **zero**, non "più veloce". Un'animazione accorciata
  /// resta un'animazione da aspettare.
  static Duration effective({required bool enabled, Duration wanted = normal}) {
    return enabled ? wanted : Duration.zero;
  }
}
