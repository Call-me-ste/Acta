import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Lo spazio da lasciare sopra il contenuto perche' non finisca sotto le
/// **notifiche del telefono**.
///
/// `MediaQuery.paddingOf(context).top` e' l'altezza della barra di stato: lo
/// sfondo va bene che ci arrivi dietro — il colore del tema fino in cima — ma le
/// **scritte** devono cominciare sotto, con un respiro che si veda. Otto pixel
/// erano "pelo pelo" all'occhio (segnalato dall'utente): sedici staccano.
///
/// Una funzione sola perche' la regola e' una: le pagine con la `AppBar`
/// ricevono gia' questo spazio (la barra lo riserva), i fogli no — ed e' li' che
/// il titolo "Nuovo" finiva sotto l'orologio.
double topInset(BuildContext context, {double extra = AppSpacing.l}) =>
    MediaQuery.paddingOf(context).top + extra;
