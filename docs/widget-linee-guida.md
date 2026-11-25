# Widget Planner — linee guida vincolanti

Ogni modifica a un widget parte da questo file. Se una regola qui non è
rispettata, il widget non è finito. Le regole nascono dalle correzioni
dell'utente e dalla vista Mese/Giorno dell'app: **il widget è l'app, non un
parente povero**.

## 1. Tipografia

- **Un solo carattere: Inter**, lo stesso dell'app (`assets/fonts/Inter-*.ttf`).
  Mai il serif o il sans di sistema, mai un font "di riferimento" diverso.
- I pesi sono quelli dell'app, non un bold messo a caso:
  - `Regular 400` — orari, testi secondari, righe lunghe;
  - `Medium 500` — numeri della griglia, etichette;
  - `SemiBold 600` — titoli, nomi dei giorni, voci di lista;
  - `Bold 700` — solo il numero hero del giorno e il titolo del mese.
- `RemoteViews` ignora `fontFamily`/`@font` e il launcher impone il suo font:
  per avere Inter davvero **il testo si disegna su `Canvas` e si mostra come
  bitmap** (`WidgetText`). Un `TextView` con `fontFamily` non è accettabile.
- Misure minime (a font di sistema 1.0):

  | Ruolo | sp | Peso |
  | --- | --- | --- |
  | Numero hero del giorno | 60 | SemiBold |
  | Nome del giorno (blocco hero) | 18 | Medium |
  | Sopratitolo mese (`OTTOBRE`) | 14.5, maiuscolo, +0.08 di spaziatura | SemiBold |
  | Titolo del mese compatto (`Ottobre 2026`) | 18 | SemiBold |
  | Numeri della griglia | 14 | Medium |
  | Intestazione giorni (`lun`) | 10.5 | SemiBold |
  | Titolo evento/To do | 15 | SemiBold |
  | Orario | 12.5 | SemiBold |
  | Etichetta sezione (`To do del giorno`) | 12.5 | SemiBold |
  | Etichetta del giorno (`OGGI · MER 28 OTT`) | 12.5 | SemiBold |
  | Conteggio sotto l'hero (`2 eventi`) | 11.5 | Medium |
  | `+N` / note | 10 | Medium |

- Sotto i 10 sp non si scende **mai**. Se non entra, si toglie un'informazione,
  non si rimpicciolisce il testo.
- Niente testo troncato: si ellissizza il titolo, mai l'orario.

## 2. Proporzioni e spazio

- Il widget è una griglia di **regioni fisse**: testata, calendario, elenco.
  Le proporzioni non cambiano con 0, 1, 2 o 100 eventi.
- **Il calendario è granitico**: cambiare giorno, aprire il To do o ricevere
  eventi non deve spostare né ridimensionare una riga del mese. Solo il giorno
  selezionato cambia (cerchio e colore).
- L'elenco vive in un'area di altezza fissa ed è **scorrevole** (collection
  Android vera). Non si allunga per mostrare più righe e non si stringe quando
  è vuoto: lo stato vuoto occupa lo stesso rettangolo.
- Il mese non si mangia il widget: in un 4x4 la griglia sta in alto per circa
  metà e la lista sotto. Niente mese gigante con il vuoto sotto.
- Padding card 12–14 dp; gap celle 1–2 dp; bersagli di tocco ≥ 36 dp (frecce,
  `+`, giorni). Il padding esterno è **simmetrico**.
- Il numero del giorno sta **dentro** il suo cerchio, con almeno 2 dp di aria:
  se il pallino è coperto dalle cifre, la cella è sbagliata.

## 3. Giorno di oggi e giorno scelto

- Comportamento dell'app: **un solo cerchio pieno**, quello del giorno scelto.
  Il widget parte con oggi selezionato; appena tocchi un altro giorno il
  cerchio si sposta e basta.
- Oggi, quando **non** è selezionato, non ha un cerchio: al massimo il numero
  nel colore d'accento. Mai due cerchi (era il bug del 4x2 e del 4x4).
- Tap su un giorno: aggiorna la selezione e la parte bassa **senza aprire
  l'app**. Il titolo/il nome del mese aprono l'app.
- Tap sulle frecce: mese precedente/successivo, dentro il widget.

## 4. Colori e identità

- Ruoli del tema, non colori inventati: sfondo, superficie, testo, tenue,
  accento, bordo (vedi `WidgetKit.colori`).
- L'accento è **uno solo** (il primario della palette). Per la densità eventi
  si usa lo stesso accento con alpha crescente (12/22/32%): si legge la
  quantità senza diventare un arcobaleno.
- Gli eventi portano il colore della loro categoria come barra/dot, come
  nell'app.
- Niente emoji, niente doppie barre, niente decorazioni senza significato.
- Forme: cerchio del giorno, pillole per i bottoni, raggi 8–20 dp; i bordi
  sono `outlineVariant`, mai grigi inventati.

## 5. Contenuti

- Sempre in italiano. Sempre **`To do`**, mai `Todo`.
- Niente riepiloghi tipo `2 eventi · 2 To do` quando la lista è già sotto: il
  conteggio vive nell'etichetta della sezione.
- Ogni widget dice una cosa sola e la dice grande.
- 0 eventi: frase breve e utile nello stesso spazio della lista ("Niente in
  programma"), mai una card mezza vuota.
- L'utente deve poter creare un evento dal widget quando c'è il `+` (apre il
  composer dell'app sulla data mostrata).

## 6. I sette widget

1. **Mese 4x2 — solo mese.** Sinistra: `OTTOBRE` (senza anno), `mercoledì`,
   numero hero, **centrati** in orizzontale e verticale. Niente frecce: il mese
   si cambia dall'app. Destra: mese compatto con intestazione giorni. Niente
   eventi, niente barre, niente To do.
2. **Mese + giorno 4x4.** In alto: hero **centrato** nella sua colonna (mese,
   giorno, numero, conteggio) e mese a destra (con frecce), densità eventi con
   l'accento. Sotto: divisore, `OGGI · mer 28 ott`, `+`, lista eventi
   scorrevole (orari visibili) e To do richiudibili.
3. **Agenda 4x4.** Striscia di 7 giorni scorrevole, giorno selezionato nel
   cerchio; lista eventi scorrevole; To do subito sotto l'ultimo evento.
4. **Giorno 2x2.** Titolo scelto (16–18), numero hero nel cerchio, niente
   liste.
5. **Mese 4x2 split.** Mini mese a sinistra, 4 righe del giorno a destra,
   To do in fondo solo se c'è spazio.
6. **Oggi 2x2.** `MAR` + `28 OTT`, lista scorrevole, stato vuoto utile.
7. **Mese 2x2.** Solo giorni, niente eventi/To do/badge.

## 7. Procedura obbligatoria

1. Rileggi questo file e la vista dell'app che il widget imita.
2. Guarda il riferimento (allegato o `plan/widget-preview-v5.png`) e lo
   screenshot reale del widget sul launcher.
3. Elenca le differenze, fai **una** modifica, ricompila.
4. Installa con `adb install -r`, aggiorna il widget, cattura lo screenshot
   reale e confronta. Solo allora dichiara finito.
5. Se il testo è piccolo, il font è sbagliato o il calendario si muove, non è
   finito.

## 8. Lezioni dai widget 1 e 2 (vincolanti)

- **Il numero hero comanda**: 60 sp. Il mese non è una didascalia: 14.5 sp
  maiuscolo, spaziato. Il giorno della settimana 18 sp. Se il mese sembra
  “piccolo piccolo” rispetto al giorno, la gerarchia è sbagliata.
- **Hero centrato nella sua colonna**, orizzontale e verticale. Non lasciare
  blocchi appoggiati in alto con il vuoto sotto.
- **Proporzioni delle colonne**: 4x2 → hero 40% / griglia 60%; 4x4 → hero 36% /
  griglia 64%. La colonna hero deve contenere `mercoledì` a 18 sp senza
  stringerlo.
- **Griglia a 6 righe fisse**, numeri 14 sp, giorni adiacenti attenuati. Un solo
  cerchio: il giorno scelto. Oggi, se non è scelto, resta normale.
- **Titolo del mese compatto**: 18 sp, mese in accento e anno in colore testo.
- **Lista**: righe 42 dp, titolo 15 sp, orario 12.5 sp, etichetta giorno 12.5,
  `+` 26 dp. Area di altezza fissa: le proporzioni non cambiano con 0, 1 o
  molti eventi.
- **Niente collection per eventi e To do**: il launcher ColorOS riusa le bitmap
  delle righe vecchie (testata fantasma) e i click della collection non sono
  affidabili. Le righe sono `RemoteViews` statiche aggiunte a una `LinearLayout`,
  con `setOnClickPendingIntent` normale. Massimo 2–3 righe per area.
- **To do compatto**: **una sola barra**, sempre in fondo, con
  `To do del giorno (N)` e Mostra/Nascondi. Aperta, i To do prendono il posto
  degli eventi (non si sovrappongono).
- **To do esteso**: niente barra; i To do sono righe nella lista, con la spunta
  che li segna direttamente nel widget (background, senza aprire l'app).
- **Click**: un evento apre l'app **sul giorno dell'evento**; un To do spunta.
  Mai una riga che non fa niente.
- **Il testo è sempre bitmap**: `WidgetText` + Inter. Se aggiungi un widget e
  vedi serif, non è finito.
- **Adapter della lista**: URI unico per widget/giorno/stato, altrimenti il
  launcher riusa il factory vecchio e la lista resta sul giorno precedente.
- **Payload giorni**: copre oggi + 7. Fuori finestra si mostrano i titoli delle
  anteprime del mese, mai dati vecchi (controlla `giornoPubblicato`).
- **Tap giorno**: aggiorna in place e non muove una riga del calendario. Il tap
  su numero/nome apre l'app; il `+` apre il composer sulla data mostrata.
- **Launcher ColorOS**: un widget nuovo va in cima e sostituisce quello nella
  stessa cella; per due widget sulla stessa pagina si aggiunge prima quello in
  basso e poi quello in alto. Il pulsante `Salva` della configurazione va
  toccato dopo aver riletto i bounds reali (la preview cambia altezza).

## 9. Errori già rifiutati

- Pallino più piccolo delle cifre o coperto dai numeri.
- Mese gigante con metà widget vuota e testi minuscoli.
- Font serif/sans di sistema al posto di Inter.
- Grassetto messo a caso su tutto.
- Calendario che si ridimensiona quando cambia il giorno o arrivano eventi.
- Oggi sempre cerchiato insieme al giorno scelto.
- To do "compatti" intesi come righe senza informazioni: devono essere una
  sezione richiudibile, non una riga mutilata.
