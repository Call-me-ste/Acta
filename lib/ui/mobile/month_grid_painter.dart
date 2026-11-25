import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../features/calendar/month_grid_geometry.dart';

/// Un giorno della griglia **gia' pronto da disegnare**: i testi sono misurati e
/// i colori risolti. Si prepara una volta per disegno della pagina, non a ogni
/// fotogramma: durante lo scorrimento fra i mesi i paragrafi sono gia' misurati e
/// si spostano soltanto.
class GiornoPronto {
  const GiornoPronto({
    required this.indice,
    required this.numero,
    required this.evidenza,
    required this.barre,
    this.oltre,
    this.badge,
  });

  /// La cella nella griglia (0 = in alto a sinistra).
  final int indice;

  /// Il numero del giorno, misurato **dentro i 30 px** della sua scatola: e' il
  /// limite che aveva anche prima (e che il font dei test fa scattare).
  final TextPainter numero;

  /// 0 = giorno normale, 1 = giorno scelto. Si anima: il pieno si accende e si
  /// spegne invece di saltare.
  final double evidenza;

  /// I colori delle barre degli eventi (fino a tre).
  final List<Color> barre;

  /// Il «+N» oltre la terza barra, gia' misurato.
  final TextPainter? oltre;

  /// Il numero dei todo del giorno, gia' misurato: il badge nell'angolo.
  final TextPainter? badge;
}

/// Disegna **tutta** la griglia del mese in una passata: i nomi dei giorni, i
/// numeri, il cerchio del giorno scelto, le barre degli eventi, il «+N» e i badge
/// dei todo.
///
/// Perche' un painter e non quarantadue celle: un cambio mese ricostruiva 62
/// celle da ~23 widget l'una — ~290 µs a cella, 13-16 ms dei 25-36 del fotogramma.
/// Qui la pagina e' **un elemento solo**, e le misure dei testi si fanno una volta
/// per pagina. Le posizioni sono le stesse di prima, al pixel: e' quello che i
/// golden verificano.
class GrigliaDelMese extends CustomPainter {
  const GrigliaDelMese({
    required this.geometria,
    required this.giorni,
    required this.nomi,
    required this.coloreCerchio,
    required this.coloreBadge,
    required this.latoNumero,
    this.premuto,
    this.coloreTinta,
  });

  final MonthGridGeometry geometria;
  final List<GiornoPronto> giorni;

  /// I nomi dei giorni per colonna (`dom lun mar…`), gia' misurati.
  final List<TextPainter> nomi;

  /// Il pieno del giorno scelto (`colorScheme.primary`).
  final Color coloreCerchio;

  /// Il fondo del badge dei todo (`colorScheme.tertiary`).
  final Color coloreBadge;

  /// Il lato del numero e del cerchio: cresce col testo, non con la scatola.
  final double latoNumero;

  /// L'indice del giorno che sta **sotto il dito**: la tinta che dice «ho
  /// sentito il tocco». Era l'inchiostro dell'`InkWell` di ogni cella; ora è un
  /// cerchio disegnato qui, per quel giorno soltanto.
  final int? premuto;

  /// Il colore di quella tinta (lo strato di stato «premuto» di Material 3).
  final Color? coloreTinta;

  /// La distanza del cerchio dal bordo alto.
  static const double bordoAlto = 3;

  /// Le barre: 3,5 px di altezza, 7 px di margine (piu' il pixel di padding della
  /// cella), 2,5 px di distacco.
  static const double altezzaBarra = 3.5;
  static const double margineBarra = 8;
  static const double distaccoBarra = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    _dipingeINomi(canvas);
    _dipingeLaTinta(canvas);
    // Una vernice sola per tutto il disegno: prima se ne creava una **per barra**
    // (~170 oggetti per pagina, ~500 per fotogramma di scorrimento regalati al
    // garbage collector), ed e' lavoro sul filo che costruisce, non sul disegno.
    // Va bene riusarla perche' qui si cambia **solo** il colore.
    final vernice = Paint();
    for (final giorno in giorni) {
      _dipingeIlGiorno(canvas, giorno, vernice);
    }
  }

  /// La tinta del giorno sotto il dito: **dietro** al numero, come l'inchiostro
  /// di prima (che si dipingeva sul `Material` sotto la cella).
  void _dipingeLaTinta(Canvas canvas) {
    final indice = premuto;
    final colore = coloreTinta;
    if (indice == null || colore == null) return;

    final cella = geometria.cellaDi(indice);
    canvas.drawCircle(
      Offset(
        cella.left + cella.width / 2,
        cella.top + bordoAlto + latoNumero / 2,
      ),
      latoNumero / 2,
      Paint()..color = colore,
    );
  }

  void _dipingeINomi(Canvas canvas) {
    for (var colonna = 0; colonna < nomi.length; colonna++) {
      final nome = nomi[colonna];
      nome.paint(
        canvas,
        Offset(
          colonna * geometria.cellWidth +
              (geometria.cellWidth - nome.width) / 2,
          (geometria.headerHeight - nome.height) / 2,
        ),
      );
    }
  }

  void _dipingeIlGiorno(Canvas canvas, GiornoPronto giorno, Paint vernice) {
    final cella = geometria.cellaDi(giorno.indice);
    final box = Rect.fromLTWH(
      cella.left + (cella.width - latoNumero) / 2,
      cella.top + bordoAlto,
      latoNumero,
      latoNumero,
    );

    // Il cerchio del giorno scelto: sempre disegnato, trasparente quando non lo
    // e', cosi' il colore si puo' interpolare.
    if (giorno.evidenza > 0) {
      canvas.drawCircle(
        box.center,
        latoNumero / 2,
        vernice
          ..color = Color.lerp(
            const Color(0x00000000),
            coloreCerchio,
            giorno.evidenza,
          )!,
      );
    }

    // Il numero, **ritagliato** nella sua scatola di 30 px: e' quello che fa anche
    // un `Text` quando il paragrafo non ci sta (col font dei test, che ha glifi
    // larghi un em, due cifre non ci stanno e si tagliano).
    //
    // Il paragrafo si centra per la sua **altezza visibile** (`min(h, 30)`) e non
    // per la sua altezza vera: il `RichText` che c'era prima veniva prima
    // limitato alla scatola e poi centrato, quindi un paragrafo piu' alto della
    // scatola partiva dall'alto, non da meta'.
    canvas.save();
    canvas.clipRect(box);
    giorno.numero.paint(
      canvas,
      Offset(
        box.left + (latoNumero - giorno.numero.width) / 2,
        box.top + (latoNumero - math.min(giorno.numero.height, latoNumero)) / 2,
      ),
    );
    canvas.restore();

    var alto = cella.top + bordoAlto + latoNumero + distaccoBarra;
    for (final colore in giorno.barre) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            cella.left + margineBarra,
            alto,
            cella.right - margineBarra,
            alto + altezzaBarra,
          ),
          const Radius.circular(2),
        ),
        vernice..color = colore,
      );
      alto += altezzaBarra + distaccoBarra;
    }

    final oltre = giorno.oltre;
    if (oltre != null) {
      oltre.paint(
        canvas,
        Offset(
          cella.left + (cella.width - oltre.width) / 2,
          alto - distaccoBarra + 2,
        ),
      );
    }

    final badge = giorno.badge;
    if (badge != null) {
      final larghezza = (badge.width + 8).clamp(15.0, double.infinity);
      final rect = Rect.fromLTWH(
        cella.right - 1 - larghezza,
        cella.top,
        larghezza,
        badge.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        vernice..color = coloreBadge,
      );
      badge.paint(
        canvas,
        Offset(
          rect.left + (rect.width - badge.width) / 2,
          rect.top + (badge.height - badge.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(GrigliaDelMese vecchio) =>
      vecchio.giorni != giorni ||
      vecchio.premuto != premuto ||
      vecchio.coloreTinta != coloreTinta ||
      vecchio.geometria.cellWidth != geometria.cellWidth ||
      vecchio.geometria.rowHeight != geometria.rowHeight ||
      vecchio.geometria.mese != geometria.mese ||
      vecchio.coloreCerchio != coloreCerchio ||
      vecchio.coloreBadge != coloreBadge;
}
