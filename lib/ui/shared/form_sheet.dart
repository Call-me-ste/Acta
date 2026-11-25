import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'motion.dart';
import 'top_inset.dart';

/// Apre un form in un foglio alto quanto serve e **che si scorre**.
///
/// Tre cose imparate con le prove, non a naso:
///
/// 1. Con `isScrollControlled: true` il foglio cresce quanto vuole il contenuto:
///    oltre lo schermo veniva **tagliato senza scroll** (il
///    `SingleChildScrollView` dentro riceveva vincoli infiniti).
/// 2. Il **maniglione** in cima era la causa più probabile della sensazione
///    «non riesco a scorrere»: sul telefono il gesto naturale è trascinare il
///    maniglione, e quello chiude il foglio invece di far scorrere il contenuto.
///    Senza maniglione e senza drag di rotta (`enableDrag: false`, che è anche
///    la linea guida di Flutter quando il contenuto è scrollabile) il gesto è
///    uno solo e non ambiguo. Si chiude con «Salva», col tasto indietro o
///    toccando fuori.
/// 3. Il cap a 9/10 dello schermo non serviva a niente e toglieva spazio proprio
///    quando serve: con la tastiera aperta il contenuto scorre **sopra** di
///    essa, e più altezza c'è, meno si deve scorrere.
Future<T?> showFormSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  /// Quanto dura l'apertura. `null` = quella di serie ([AppMotion.slow]).
  ///
  /// A `Duration.zero` il foglio compare gia' completo: serve alla **prima**
  /// apertura di un form, l'unica che paga la prima rasterizzazione del suo
  /// contenuto (misurato sul telefono: +22 ms di raster, contro 4 delle
  /// aperture successive). Con un'animazione quella spesa diventa uno scatto
  /// mentre il foglio sale; ferma, diventa un fotogramma di attesa.
  Duration? durataApertura,
  bool isDismissible = true,
}) {
  // La barra di stato si legge **da fuori**: dentro un foglio il framework
  // toglie quel padding dall'albero (il foglio puo' partire dal bordo dello
  // schermo), quindi li' `MediaQuery.padding.top` vale zero. Senza questa
  // lettura, il titolo "Nuovo" del form finiva nella zona delle notifiche.
  final sopra = topInset(context);

  return showActaSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: false,
    showDragHandle: false,
    // La transizione del foglio segue la regola delle altre animazioni: un po'
    // piu' lenta di quella di serie (250 ms), per lo stesso motivo — il
    // movimento piu' lungo perdona meglio un fotogramma pesante. In chiusura
    // resta svelta (`fast`): chiudere non e' un movimento da ammirare.
    animationStyle: AnimationStyle(
      duration: durataApertura ?? AppMotion.slow,
      reverseDuration: AppMotion.fast,
    ),
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height,
      ),
      // Lo sfondo del foglio arriva fino in cima (dietro le notifiche), le
      // scritte no: cominciano sotto la barra di stato, con un piccolo respiro.
      child: Padding(
        padding: EdgeInsets.only(top: sopra),
        child: builder(sheetContext),
      ),
    ),
  );
}
