import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/design_tokens.dart';

/// Il comando che riporta a oggi, quando il giorno che stai guardando non e' oggi.
///
/// Perche' un pulsante e non un tocco sulla data: quando ti sei allontanato di tre
/// mesi, tornare a oggi con le freccette sono nove tocchi. Il pulsante compare
/// **solo** se serve (se stai gia' guardando oggi non c'e').
///
/// Perche' **dice la data** e non e' un cerchio con l'icona: la recensione l'aveva
/// segnato — «non dice *dove* ti riporta». «Oggi 17 set» lo dice: chi ha girato tre
/// mesi vede subito dove finira', senza doverlo provare. Il tooltip resta, ed e'
/// anche l'etichetta di accessibilita': una sola verita'.
///
/// Forma e famiglia visiva sono quelle della pillola delle viste e del «Nuovo».
class BackToTodayButton extends StatelessWidget {
  const BackToTodayButton({
    super.key,
    required this.onPressed,
    required this.today,
  });

  final VoidCallback onPressed;

  /// Il giorno verso cui riporta. Arriva da fuori e non da `DateTime.now()` qui
  /// dentro: una data letta dentro un widget non si puo' provare.
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Torna a oggi',
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        ),
        icon: const Icon(Icons.today, size: AppSpacing.iconSmall),
        label: Text('Oggi ${DateFormat('d MMM', 'it_IT').format(today)}'),
      ),
    );
  }
}
