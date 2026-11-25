import 'package:flutter/material.dart';

import '../../features/todos/todo_entry.dart';
import '../../theme/design_tokens.dart';
import 'row_collapse.dart';
import 'todo_section_header.dart';
import 'todo_tile.dart';

/// Una riga **descritta**, non ancora costruita: la lista la trasforma in widget
/// solo quando entra nello schermo. Con 2.000 todo, costruire tutte le `TodoTile`
/// in anticipo era il costo da 580 ms misurato in JIT.
sealed class RigaElenco {
  const RigaElenco();
}

class RigaIntestazione extends RigaElenco {
  const RigaIntestazione({
    required this.titolo,
    required this.icona,
    required this.count,
    required this.open,
    required this.onToggle,
    this.errore = false,
  });

  final String titolo;
  final IconData icona;
  final int count;
  final bool open;
  final VoidCallback onToggle;
  final bool errore;
}

class RigaTodo extends RigaElenco {
  const RigaTodo(this.entry, {this.chiusura = false});

  final TodoEntry entry;
  final bool chiusura;
}

class RigaSpazio extends RigaElenco {
  const RigaSpazio();
}

/// Costruisce la riga al momento in cui serve.
Widget costruisciRiga(BuildContext context, RigaElenco riga) {
  return switch (riga) {
    RigaIntestazione i => TodoSectionHeader(
        title: i.titolo,
        icon: i.icona,
        count: i.count,
        open: i.open,
        onToggle: i.onToggle,
        color: i.errore ? Theme.of(context).colorScheme.error : null,
      ),
    RigaTodo t => t.chiusura
        ? RigaCheSiChiude(child: TodoTile(entry: t.entry))
        : TodoTile(entry: t.entry),
    RigaSpazio() => const SizedBox(height: AppSpacing.xl),
  };
}
