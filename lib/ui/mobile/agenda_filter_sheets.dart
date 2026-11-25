import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/categories/category_controller.dart';
import '../../features/filters/filtro_condiviso_controller.dart';
import '../../theme/design_tokens.dart';
import '../shared/top_inset.dart';

/// I fogli delle scelte del **filtro condiviso**: le voci di una scelta a voce
/// unica, e le categorie a scelta multipla.
///
/// Due funzioni e non due widget: chi chiama vuole *aprire* un foglio, e i
/// widget restano privati qui dentro — il file ha una cosa sola da dire (com'è
/// fatto un foglio dei filtri) e chi lo usa non deve conoscerne la forma.
Future<void> showSceltaSheet<T>(
  BuildContext context, {
  required String titolo,
  required List<T> opzioni,
  required T attuale,
  required String Function(T) etichetta,
  required ValueChanged<T> onScelto,
  IconData Function(T)? icona,
}) async {
  final scelta = await showActaSheet<T>(
    context: context,
    showDragHandle: true,
    constraints: _tetto(context),
    builder: (_) => _FoglioScelta<T>(
      titolo: titolo,
      opzioni: opzioni,
      attuale: attuale,
      etichetta: etichetta,
      icona: icona,
    ),
  );
  // Scegliere quello che era già scelto non è un cambiamento: non si scrive una
  // preferenza identica (e non si ricostruisce niente).
  if (scelta != null && scelta != attuale) onScelto(scelta);
}

/// Il foglio delle **categorie**, a scelta multipla.
Future<void> showCategorieSheet(BuildContext context) async {
  await showActaSheet<void>(
    context: context,
    showDragHandle: true,
    constraints: _tetto(context),
    builder: (_) => const _FoglioCategorie(),
  );
}

/// Il tetto di altezza di un foglio: dentro un foglio la barra di stato non è
/// disponibile, quindi si legge da chi lo apre (vedi `topInset`).
BoxConstraints _tetto(BuildContext context) => BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height - topInset(context),
    );

/// La forma di un foglio dei filtri: titolo, spiegazione breve, e le voci.
///
/// Una sola perché i due fogli sono la stessa cosa con dentro cose diverse:
/// ripetere l'impalcatura è il modo in cui due fogli finiscono per comportarsi
/// in due modi.
class _Foglio extends StatelessWidget {
  const _Foglio({required this.titolo, this.spiegazione, required this.voci});

  final String titolo;
  final String? spiegazione;
  final List<Widget> voci;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titolo, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.m),
            if (spiegazione != null) ...[
              Text(
                spiegazione!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
            ],
            ...voci,
          ],
        ),
      ),
    );
  }
}

/// Un foglio con le voci di una scelta e la spunta su quella in corso.
class _FoglioScelta<T> extends StatelessWidget {
  const _FoglioScelta({
    required this.titolo,
    required this.opzioni,
    required this.attuale,
    required this.etichetta,
    this.icona,
  });

  final String titolo;
  final List<T> opzioni;
  final T attuale;
  final String Function(T) etichetta;
  final IconData Function(T)? icona;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Foglio(
      titolo: titolo,
      voci: [
        for (final opzione in opzioni)
          ListTile(
            key: ValueKey('scelta-${opzione is Enum ? opzione.name : opzione}'),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.s),
            leading: icona == null ? null : Icon(icona!(opzione)),
            title: Text(etichetta(opzione)),
            trailing: opzione == attuale
                ? Icon(Icons.check, color: theme.colorScheme.primary)
                : null,
            onTap: () => Navigator.pop(context, opzione),
          ),
      ],
    );
  }
}

/// Le categorie a scelta multipla: pastiglie che si accendono e si spengono
/// (rimetterle in una fila di voci con la spunta sarebbe la stessa cosa detta
/// peggio). Elenco vuoto = nessun vincolo, e il foglio lo dice con le parole:
/// «tutte» non è una voce da scegliere, è la partenza.
class _FoglioCategorie extends StatelessWidget {
  const _FoglioCategorie();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<FiltroCondivisoController>();
    final categorie = context.watch<CategoryController>().all;
    final scelte = controller.filtro.categorieScelte;

    return _Foglio(
      titolo: 'Categorie',
      spiegazione: scelte.isEmpty
          ? 'Nessun vincolo: si vede tutto.'
          : 'Si vede solo quello che ha una di queste.',
      voci: [
        if (categorie.isEmpty)
          Text(
            'Nessuna categoria: si creano da Impostazioni > Categorie.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.xs,
            children: [
              for (final categoria in categorie)
                FilterChip(
                  key: ValueKey('filtro-categoria-${categoria.id}'),
                  label: Text(
                    categoria.emoji.isEmpty
                        ? categoria.name
                        : '${categoria.emoji} ${categoria.name}',
                  ),
                  selected: scelte.contains(categoria.id),
                  showCheckmark: false,
                  onSelected: (_) => controller.toggleCategoria(categoria.id),
                ),
            ],
          ),
      ],
    );
  }
}
