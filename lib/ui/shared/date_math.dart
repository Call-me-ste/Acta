import 'package:flutter/material.dart';

/// La data **senza orario**: mezzanotte di quel giorno.
///
/// Sembra banale e non lo è: `DateTime(y, m, d)` normalizza anche i giorni fuori
/// range (il 32 diventa il 1 del mese dopo), ed è l'unica aritmetica corretta per
/// le date. Nel progetto questa riga era scritta **dodici volte** in file diversi:
/// dodici posti in cui sbagliarla allo stesso modo.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// I minuti dalla mezzanotte di un orario scelto dall'utente.
///
/// Il form lavora in minuti (le regole degli orari stanno in
/// `features/events/domain/time_rules.dart`) e `TimeOfDay` è il tipo del
/// selettore Material: la conversione sta qui una volta sola.
int minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;
