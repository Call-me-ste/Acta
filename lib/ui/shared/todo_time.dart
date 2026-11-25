import 'package:flutter/material.dart';

/// L'ora dei todo, in un posto solo: la riga di riepilogo del form e le righe
/// dell'elenco devono dire la stessa cosa, e due formattazioni diverse per la
/// stessa cosa si allontanano alla prima modifica.
///
/// L'ora la scrive `MaterialLocalizations`, come nel form degli eventi: 12 o 24
/// ore secondo il sistema, non secondo una scelta nostra.
String oraBreve(BuildContext context, int minuti) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: minuti ~/ 60, minute: minuti % 60),
    );

/// L'orario di un todo come si legge: «08:00 - 09:00», «dalle 08:00»,
/// «entro le 18:00», oppure `null` quando il todo ha solo la data.
///
/// «dalle» e «entro le» non sono decorazione: un todo con il solo inizio e uno
/// con la sola fine sono due cose diverse (quando lo fai / quando deve essere
/// fatto), e senza la parola si leggerebbero uguali.
String? todoTimeLabel(
  BuildContext context, {
  int? startMinutes,
  int? endMinutes,
}) {
  if (startMinutes == null && endMinutes == null) return null;
  if (startMinutes != null && endMinutes != null) {
    return '${oraBreve(context, startMinutes)} - ${oraBreve(context, endMinutes)}';
  }
  if (startMinutes != null) return 'dalle ${oraBreve(context, startMinutes)}';
  return 'entro le ${oraBreve(context, endMinutes!)}';
}
