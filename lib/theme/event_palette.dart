/// I colori **standard** degli elementi: eventi, todo, categorie.
///
/// Non derivano dalla palette del tema. La palette governa superfici, testo e
/// accento; il colore di un evento è un'identità e deve restare lo stesso quando
/// si cambia tema. Sono tinte Material/One UI riadattate, non asset Samsung.
class EventPalette {
  const EventPalette._();

  static const List<String> colors = [
    '#E53935', // rosso
    '#FB8C00', // arancio
    '#FDD835', // giallo
    '#7CB342', // verde
    '#00897B', // verde acqua
    '#00ACC1', // ciano
    '#1E88E5', // blu
    '#3949AB', // indaco
    '#8E24AA', // viola
    '#D81B60', // magenta
    '#EC407A', // rosa
    '#6D4C41', // marrone
    '#546E7A', // grigio
    '#26A69A', // teal
    '#FF7043', // corallo
    '#5C6BC0', // pervinca
  ];

  static int get length => colors.length;

  /// Il colore per indice, in modo ciclico: un indice vecchio non sparisce.
  static String at(int index) {
    if (colors.isEmpty) return '#5C6BC0';
    final safe = ((index % colors.length) + colors.length) % colors.length;
    return colors[safe];
  }
}
