/// Un elemento “smart” trovato nel testo di una nota.
enum SmartLinkKind { url, phone, date }

class SmartLink {
  const SmartLink({
    required this.kind,
    required this.text,
    this.date,
    this.index = 0,
  });

  final SmartLinkKind kind;
  final String text;

  /// Valorizzata solo per [SmartLinkKind.date].
  final DateTime? date;

  /// Posizione nel testo, per mantenere l'ordine di lettura.
  final int index;
}

/// Estrae URL, telefoni e date italiane dal testo. È tutto locale e
/// deterministico: nessuna AI, nessuna rete.
List<SmartLink> estraiSmartLinks(String testo) {
  final trovati = <SmartLink>[];
  var resto = testo;

  void maschera(int inizio, int fine) {
    resto = resto.replaceRange(inizio, fine, ' ' * (fine - inizio));
  }

  // URL: prima di tutto, così i numeri dentro un link non diventano telefoni.
  final url = RegExp(r'https?://[^\s]+', caseSensitive: false);
  for (final match in url.allMatches(testo)) {
    var testoUrl = match.group(0)!;
    while (testoUrl.isNotEmpty &&
        '.,;:!?)]}'.contains(testoUrl[testoUrl.length - 1])) {
      testoUrl = testoUrl.substring(0, testoUrl.length - 1);
    }
    trovati.add(SmartLink(
      kind: SmartLinkKind.url,
      text: testoUrl,
      index: match.start,
    ));
    maschera(match.start, match.start + testoUrl.length);
  }

  // Date numeriche: 14/10, 14-10-2026, 14.10.26.
  final dateNumeriche = RegExp(
    r'\b(\d{1,2})[\/.-](\d{1,2})(?:[\/.-](\d{2,4}))?\b',
  );
  for (final match in dateNumeriche.allMatches(resto)) {
    final giorno = int.tryParse(match.group(1)!);
    final mese = int.tryParse(match.group(2)!);
    final annoGrezzo = match.group(3);
    final anno = annoGrezzo == null
        ? DateTime.now().year
        : (annoGrezzo.length == 2
            ? 2000 + int.parse(annoGrezzo)
            : int.parse(annoGrezzo));
    final data = _dataValida(anno, mese, giorno);
    if (data == null) continue;
    trovati.add(SmartLink(
      kind: SmartLinkKind.date,
      text: match.group(0)!,
      date: data,
      index: match.start,
    ));
    maschera(match.start, match.end);
  }

  // Date con il mese scritto: 14 ottobre, 3 marzo 2027.
  final dateParole = RegExp(
    r'\b(\d{1,2})\s+(gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre)(?:\s+(\d{4}))?\b',
    caseSensitive: false,
  );
  for (final match in dateParole.allMatches(resto)) {
    final mese = _mesi[match.group(2)!.toLowerCase()];
    final anno = match.group(3) == null
        ? DateTime.now().year
        : int.parse(match.group(3)!);
    final data = _dataValida(anno, mese, int.tryParse(match.group(1)!));
    if (data == null) continue;
    trovati.add(SmartLink(
      kind: SmartLinkKind.date,
      text: match.group(0)!,
      date: data,
      index: match.start,
    ));
    maschera(match.start, match.end);
  }

  // Telefoni: almeno 8 cifre, con spazi o + iniziale. Niente slash, così le
  // date non vengono scambiate per numeri.
  final telefono = RegExp(r'\+?\d[\d\s]{6,}\d');
  for (final match in telefono.allMatches(resto)) {
    final cifre = match.group(0)!.replaceAll(RegExp(r'\D'), '');
    if (cifre.length < 8 || cifre.length > 15) continue;
    trovati.add(SmartLink(
      kind: SmartLinkKind.phone,
      text: match.group(0)!.trim(),
      index: match.start,
    ));
    maschera(match.start, match.end);
  }

  trovati.sort((a, b) => a.index.compareTo(b.index));
  final visti = <String>{};
  return [
    for (final link in trovati)
      if (visti.add('${link.kind.name}|${link.text}')) link,
  ];
}

const Map<String, int> _mesi = {
  'gennaio': 1,
  'febbraio': 2,
  'marzo': 3,
  'aprile': 4,
  'maggio': 5,
  'giugno': 6,
  'luglio': 7,
  'agosto': 8,
  'settembre': 9,
  'ottobre': 10,
  'novembre': 11,
  'dicembre': 12,
};

/// Una data senza anno che è già passata si riferisce all'anno prossimo.
DateTime? _dataValida(int anno, int? mese, int? giorno) {
  if (mese == null || giorno == null) return null;
  if (mese < 1 || mese > 12 || giorno < 1 || giorno > 31) return null;
  final data = DateTime(anno, mese, giorno);
  if (data.month != mese || data.day != giorno) return null;
  final oggi = DateTime.now();
  final senzaAnno = DateTime(oggi.year, mese, giorno);
  if (senzaAnno.isBefore(DateTime(oggi.year, oggi.month, oggi.day))) {
    final prossimo = DateTime(oggi.year + 1, mese, giorno);
    if (data.year == oggi.year) return prossimo;
  }
  return data;
}
