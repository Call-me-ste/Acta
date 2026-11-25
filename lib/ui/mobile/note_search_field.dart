import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// La ricerca delle note: una superficie unica, non una riga sottolineata.
///
/// È la stessa forma della ricerca di Samsung Notes: campo pieno, angoli
/// arrotondati, icona a sinistra. Il pulsante di pulizia compare solo quando
/// c'è qualcosa da pulire.
class NoteSearchField extends StatelessWidget {
  const NoteSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s,
        AppSpacing.page,
        AppSpacing.s,
      ),
      child: TextField(
        key: const ValueKey('cerca-note'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cerca note',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Pulisci',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close),
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.s,
          ),
        ),
      ),
    );
  }
}
