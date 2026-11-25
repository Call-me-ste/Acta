import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'item_actions.dart';
import 'item_type.dart';
import '../shared/motion.dart';
import '../shared/view_switcher_pill.dart';

/// L'intestazione del form: cosa si sta facendo e, in creazione, di che tipo.
///
/// In **modifica** la pillola Evento/Todo non c'è: cambiare tipo a qualcosa che
/// esiste già non è una modifica, è una conversione — e il form non la fa.
class ItemFormHeader extends StatelessWidget {
  const ItemFormHeader({
    super.key,
    required this.editing,
    required this.type,
    required this.onType,
    required this.onClose,
    required this.onSave,
  });

  final bool editing;
  final ItemType type;
  final ValueChanged<ItemType> onType;
  final VoidCallback? onClose;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('chiudi-form'),
              tooltip: 'Annulla',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                editing ? 'Modifica' : 'Nuovo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ItemActions(onSave: onSave),
          ],
        ),
        if (!editing) ...[
          const SizedBox(height: AppSpacing.s),
          ViewSwitcherPill<ItemType>(
            entries: const [
              ViewSwitcherEntry(value: ItemType.evento, label: 'Evento'),
              ViewSwitcherEntry(value: ItemType.todo, label: 'To do'),
            ],
            value: type,
            onChanged: onType,
            animate: animationsOn(context),
          ),
        ],
      ],
    );
  }
}
