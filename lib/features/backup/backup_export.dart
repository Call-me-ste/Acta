import 'package:share_plus/share_plus.dart';

/// L'unica porta verso il **foglio di condivisione** del sistema: da li' la copia
/// va su Drive, su Files, sul PC, dove vuoi tu.
///
/// Perche' un file suo da dieci righe: `share_plus` e' l'unica dipendenza nuova di
/// tutto il blocco delle copie, e tenerla isolata significa che si puo' leggere
/// tutto quello che fa (e sostituirla) senza toccare nient'altro. La pagina riceve
/// questa funzione come parametro, cosi' nei test si mette una finta e non si
/// parla con il sistema.
///
/// Non c'e' il percorso inverso — *leggere* un file scelto da te: servirebbe un
/// selettore di file che il progetto non ha. Il ripristino si fa dall'elenco
/// interno; l'import da un file esterno e' la voce di coda #160.
Future<void> condividiCopia(String percorso) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(percorso)],
      subject: 'Copia di sicurezza del Planner',
      text: 'Copia di sicurezza di Planner.',
    ),
  );
}
