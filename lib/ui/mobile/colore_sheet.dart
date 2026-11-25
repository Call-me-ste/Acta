import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/motion.dart';
import '../../features/palette/domain/palette.dart';
import '../../features/palette/domain/presets.dart';
import '../../features/palette/domain/tono.dart';
import '../../features/palette/palette_controller.dart';
import '../../features/settings/app_settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/color_resolver.dart';
import '../../theme/design_tokens.dart';
import '../shared/color_field.dart';
import '../shared/color_name.dart';
import '../shared/top_inset.dart';
import 'color_box.dart';
import 'theme_preview.dart';

/// Il foglio del colore, **minimo**: l'anteprima e **una riga** di scelta.
///
/// È la strada principale della personalizzazione, e sta in un foglio perché le
/// scelte sono poche: si apre da una riga sola («Impostazioni › Aspetto › Tema e
/// colori»), si tocca un colore e si guarda il risultato — l'anteprima è lì
/// dentro, e l'app dietro cambia **davvero**, perché la scelta si applica subito
/// e non c'è niente da confermare.
///
/// Le scelte sono due, e sono le stesse di un telefono: un **colore con un
/// nome** (che è un tema completo: colore del tema e colori degli elementi) o
/// **un colore tuo**, dalla ruota. Nient'altro: i gruppi doppi e i temi di
/// scorta erano il «farragginoso» della segnalazione.
Future<void> showColoreSheet(BuildContext context) {
  return showActaSheet<void>(
    context: context,
    // Senza questo il foglio si ferma a **9/16** dello schermo (il limite di
    // default dei `showModalBottomSheet`): con l'anteprima in cima le caselle
    // resterebbero sotto la piega — nascoste a chi non pensa a tirare su il
    // foglio.
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height - topInset(context),
    ),
    builder: (_) => const _FoglioColore(),
  );
}

/// Come si chiama il colore attivo, per chi lo legge: il nome del tema pronto,
/// o il nome italiano del colore se il tema è tuo.
String nomeDelColore(
  Palette palette, {
  TonoTema tono = TonoTema.naturale,
}) {
  final String nome;
  if (palette.isPreset) {
    nome = palette.name;
  } else if (palette.simpleColors.isNotEmpty) {
    nome = 'Personalizzato';
  } else {
    final colore = ColorResolver.hexToColor(palette.seedHex);
    nome = colore == null ? palette.name : colorNameFor(colore);
  }
  return tono == TonoTema.naturale ? nome : '$nome · ${tono.etichetta}';
}

/// Apre la ruota e scrive il colore scelto sul **tema tuo**: il colore diventa
/// il tema, e i colori degli elementi diventano la sua famiglia curata più
/// vicina.
///
/// Il tema tuo è **uno solo**: scegliere di nuovo riscrive quello, non ne crea
/// un secondo (era il modo per ritrovarsi dieci «Colore personale»).
Future<void> scegliAltroColore(BuildContext context) async {
  final palettes = context.read<PaletteController>();
  final settings = context.read<AppSettingsController>();

  final hex = await showColorDialog(
    context,
    // La ruota parte dal colore **che si vede adesso**, tono compreso: così
    // anteprima e cursore dicono la stessa cosa. Il colore scelto diventa il
    // tema tuo e il tono torna Naturale: altrimenti il tono si applicherebbe
    // una seconda volta sopra la scelta appena fatta.
    initialHex: palettes.resolve(settings.activePaletteId).seedHex,
    title: PaletteController.myColorName,
  );
  if (hex == null) return;

  final daScrivere = palettes.conColore(hex);
  await palettes.save(daScrivere);
  palettes.setTono(TonoTema.naturale);
  if (!context.mounted) return;
  settings.setActivePalette(daScrivere.id);
}

/// La casella di un **colore pronto**: la tinta del tema, la striscia dei suoi
/// colori degli elementi e il nome. Si sceglie guardando, e il nome serve a
/// ritrovare quella di prima — due blu si somigliano.
Widget _pronto(
  BuildContext context,
  AppSettingsController settings,
  Palette palette,
  String attivaId,
  TonoTema tono,
) {
  // La casella mostra il tono scelto: se no il foglio direbbe «Pastello» e le
  // tinte resterebbero quelle di prima.
  final mostrata = applicaTono(palette, tono);
  return ColorBox(
    key: ValueKey('tinta-${palette.id}'),
    colore: ColorResolver.hexToColor(mostrata.seedHex) ??
        Theme.of(context).colorScheme.primary,
    contenuto: ColorStrip(palette: mostrata),
    etichetta: palette.name,
    attiva: palette.id == attivaId,
    onTap: () => settings.setActivePalette(palette.id),
  );
}

/// La casella **«Il mio colore»**: la ruota. Se un colore tuo c'è già, si vede
/// anche quello — tinta, striscia e stato attivo: prima mancava, ed era la
/// parte «incompleta» della segnalazione.
Widget _mioColore(
  BuildContext context,
  PaletteController palettes,
  Palette attiva,
) {
  final theme = Theme.of(context);
  final fallback = theme.colorScheme.surfaceContainerHigh;
  final mio = palettes.byId(PaletteController.myColorId);
  final mostrato = mio == null ? null : applicaTono(mio, palettes.tono);
  final seme =
      mostrato == null ? null : ColorResolver.hexToColor(mostrato.seedHex);

  return ColorBox(
    key: const ValueKey('altro-colore'),
    colore: seme ?? fallback,
    contenuto: mostrato == null
        ? Icon(Icons.palette_outlined, color: theme.colorScheme.onSurface)
        : ColorStrip(palette: mostrato),
    etichetta: PaletteController.myColorName,
    conBordo: true,
    attiva: mio != null && mio.id == attiva.id,
    onTap: () => scegliAltroColore(context),
  );
}

/// Il foglio vero e proprio: un widget suo e **piccolo**, che si iscrive da sé
/// ai due controller. L'ascolto sta qui e non nella pagina delle impostazioni:
/// così cambiare colore ricostruisce queste poche righe, non tutta la pagina.
class _FoglioColore extends StatelessWidget {
  const _FoglioColore();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final palettes = context.watch<PaletteController>();
    final attiva = palettes.resolve(settings.activePaletteId);
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. **Anteprima**: la giornata in miniatura, dal vivo. Sta in cima
            // perché è la risposta alla domanda «come diventa l'app?».
            RigaDelFoglio(
              titolo: 'Anteprima',
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: ThemePreview(
                    scheme: AppTheme.schemeFor(attiva, theme.brightness),
                  ),
                ),
              ),
            ),
            // 2. **Colore principale**: gli otto colori curati e la casella
            // della ruota, in una riga sola che va a capo da sé.
            RigaDelFoglio(
              titolo: 'Colore principale',
              child: _Griglia(
                caselle: [
                  for (final palette in presetColori)
                    _pronto(
                      context,
                      settings,
                      palette,
                      attiva.id,
                      palettes.tono,
                    ),
                  _mioColore(context, palettes, attiva),
                ],
              ),
            ),
            // 3. **Tono**: la stessa famiglia, con un'altra voce. Non crea
            // palette: cambia la lente sopra quella attiva.
            RigaDelFoglio(
              titolo: 'Tono',
              child: _Toni(
                tono: palettes.tono,
                onChanged: palettes.setTono,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// I quattro toni, con la descrizione di quello scelto: le parole dicono
/// l'effetto, non il gergo («Pastello», non «saturazione 55%»).
class _Toni extends StatelessWidget {
  const _Toni({required this.tono, required this.onChanged});

  final TonoTema tono;
  final ValueChanged<TonoTema> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            for (final valore in TonoTema.values)
              ChoiceChip(
                key: ValueKey('tono-${valore.name}'),
                label: Text(valore.etichetta),
                selected: valore == tono,
                onSelected: (_) => onChanged(valore),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tono.descrizione,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Le caselle di una riga, **a capo da sole**: due righe di colori su un
/// telefono normale, qualcuna in piu' col testo ingrandito. Non si contano i
/// posti a mano: lo fa il `Wrap`, che non trabocca mai.
class _Griglia extends StatelessWidget {
  const _Griglia({required this.caselle});

  final List<Widget> caselle;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.m,
        runSpacing: AppSpacing.m,
        children: caselle,
      );
}

/// Una riga del foglio: un titolo e il suo contenuto. Le due righe del foglio
/// hanno tutte questa forma, quindi si legge come un elenco — e non serve
/// indovinare dove finisce una scelta e dove comincia la successiva.
class RigaDelFoglio extends StatelessWidget {
  const RigaDelFoglio({
    super.key,
    required this.titolo,
    required this.child,
  });

  final String titolo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titolo, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.s),
          child,
        ],
      ),
    );
  }
}
