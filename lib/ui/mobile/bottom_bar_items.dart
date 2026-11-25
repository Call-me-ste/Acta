part of 'bottom_bar.dart';

/// Una voce normale: icona, etichetta, e tutta la cella è toccabile.
class _Voce extends StatelessWidget {
  const _Voce({
    required this.voce,
    required this.selezionata,
    required this.onTap,
  });

  final ({IconData icona, IconData iconaPiena, String etichetta}) voce;
  final bool selezionata;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selezionata,
      label: voce.etichetta,
      child: InkWell(
        key: ValueKey('barra-${voce.etichetta}'),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              height: BottomBar.diametroPastiglia - BottomBar.rigonfiamento,
              child: Center(
                child: Icon(
                  selezionata ? voce.iconaPiena : voce.icona,
                  size: AppSpacing.icon + 4,
                  color:
                      selezionata ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
            ExcludeSemantics(
              child: Text(
                voce.etichetta == 'Impostazioni' ? 'Opzioni' : voce.etichetta,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selezionata
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      fontWeight: selezionata ? FontWeight.w600 : null,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'etichetta sotto la pastiglia: sta sulla barra, non sulla collina, ed è
/// **toccabile** come la pastiglia — chi mira alla parola invece che al cerchio
/// deve ottenere la stessa cosa. La semantica però sta solo sulla pastiglia: una
/// destinazione, un annuncio.
class _EtichettaCentrale extends StatelessWidget {
  const _EtichettaCentrale({
    required this.testo,
    required this.selezionata,
    required this.onTap,
  });

  final String testo;
  final bool selezionata;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: InkWell(
        key: const ValueKey('barra-etichetta-centro'),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Lo spazio che la pastiglia occupa **dentro** la barra: sotto di lei
            // ci va l'etichetta, e senza questo salirebbe dentro la collina.
            const SizedBox(
              height: BottomBar.diametroPastiglia - BottomBar.rigonfiamento,
            ),
            Text(
              testo,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selezionata
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                    fontWeight: selezionata ? FontWeight.w600 : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La pastiglia rialzata: dello **stesso colore della barra** (si fonde con essa,
/// è una collina) e con l'icona più grande. Selezionata, l'icona prende il colore
/// dell'accento e il cerchio si accende di un anello.
class _Pastiglia extends StatelessWidget {
  const _Pastiglia({
    required this.voce,
    required this.selezionata,
    required this.onTap,
  });

  final ({IconData icona, IconData iconaPiena, String etichetta}) voce;
  final bool selezionata;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selezionata,
      label: voce.etichetta,
      child: InkWell(
        key: const ValueKey('barra-pastiglia'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: BottomBar.diametroPastiglia,
          height: BottomBar.diametroPastiglia,
          decoration: BoxDecoration(
            // Il colore **della barra**: è quello che fa la collina.
            color: scheme.surfaceContainerLow,
            shape: BoxShape.circle,
            border: Border.all(
              color: selezionata ? scheme.onSurface : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(
            selezionata ? voce.iconaPiena : voce.icona,
            size: AppSpacing.icon + 10,
            color: selezionata ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
