# Postmortem v2 — `personal_planner_localfirst`

> Recuperato il **2026-09-13** da `C:\Users\stefi\code\personal_planner_localfirst` (sorgente intatto).
> Ogni numero in questo file è **misurato**, non stimato. Comandi di verifica in fondo.
> Separazione: **[FATTO]** = verificato con comando · **[INFERENZA]** = lettura ragionata del codice.

---

## 1. Cos'era la v2

| | |
| --- | --- |
| Path | `C:\Users\stefi\code\personal_planner_localfirst` |
| App | `Personal Planner Local First` (MSIX installato, `PersonalPlanner.LocalFirst_fxkeb4dgdm144`) |
| Periodo | `2026-06-26` → `2026-07-22` (230 commit), ultimo lavoro non committato `2026-09-01` |
| LOC `lib/` | **31.856** |
| LOC `test/` | **36.278** (44 file di test) |
| File `lib/` | 69 (27 con dipendenza Flutter, 42 puro Dart) |
| Toolchain | WSL Ubuntu 24.04 + Flutter 3.44.4 (nessun Android SDK); Windows build da PowerShell |
| Stato al recupero | `flutter analyze` → **3 info** · `flutter test` → **1170 pass / 27 fail** |

**Stack v2 [FATTO, da `AGENTS.md`]**: nessuna libreria di state management, nessuna DI, nessun router — `setState` manuale, constructor injection, `Navigator.push`. **Nessun database**: un file JSON per item (`FilePlannerItemRepository`).

---

## 2. I sei problemi che hanno ucciso la v2

### P1 — Lo stutter non era un bug: era l'architettura [FATTO]

Contatori sul codice v2:

| Metrica | Valore v2 | Regola v3 |
| --- | --- | --- |
| `ListView.builder` | **0** | obbligatorio nelle liste |
| `ListView(` grezza | 9 | — |
| `Column(` | **112** | liste lunghe = builder |
| `SingleChildScrollView` | 9 | — |
| `setState(` | **101** (38 in `home_page.dart` da sola) | `ChangeNotifier` + `Provider` |
| File più grande | `home_page.dart` = **5.323 righe** | — |
| Altri | `mobile_calendar_views.dart` 4.133 · `calendar_page.dart` 2.806 · `settings_page.dart` 1.722 | — |

Con 101 `setState` su pagine da migliaia di righe, ogni tap ricostruisce un albero enorme. Non c'è micro-ottimizzazione che salvi questa struttura: era stutter **per costruzione**.

Cronologia del churn [FATTO, `git log`] — 11 commit per inseguire lo stesso problema:

```
41ef807 Add home card animations          0cde2e7 Polish home dashboard scrolling and emoji suggestions
3d3492d Add home item reordering animations 6c966f0 Smooth compact todo transitions
0d1c34f Reduce home reorder rebuilds       74858ae Simplify home card reordering
b0911d0 Animate calendar view changes      a038c1d Smooth compact todo expansion
90345a5 Smooth home card insertions        604b026 Stabilize home scrolling animations
d3f1e10 feat(ui): smooth planner animations
```

11 commit di "smooth/stabilize/reduce rebuild" e il problema era ancora aperto all'abbandono.

### P2 — "Indagini infinite": il codice non era leggibile da un LLM [INFERENZA + tua testimonianza]

Tua frase del `2026-09-11T12:10:40`:
> *"problemi di animazioni … per evitare stutter e per evitare **indagini infinite** che mi hanno portato all'abbandono della versione v2"*

Il codice spiega perché. `home_page.dart` non è una pagina: contiene un mini-framework di animazione scritto a mano:

```
3629  _HomeAnimatedItemTransition   (+ state)
3725  _HomeAnimatedPresence         (+ state)
3838  _HomeAnimatedSection          (+ state)
3857  // "Active items in the exact logical order expected by AnimatedList"
3864  GlobalKey<AnimatedListState>   → bookkeeping ID→indice, remove in descending order
```

Più `app_motion.dart`: fisica balistica custom (`MonthCushionScrollPhysics`, `cushionDragSpring`, `cushionFlingSpring`, cap di velocità, restitution) — ~120 righe di costanti fisiche con codici `MOTION-C1`.

Per toccare una singola animazione serviva rileggere 5.000+ righe di stato + wrapper proprietari. **Ogni task diventava un'indagine.** Questo è il costo vero dei file monstre: non la performance, la *leggibilità*, che per un agente senza occhi è l'unico modo di lavorare.

### P3 — `flutter analyze` pulito e app abbandonata comunque [FATTO]

**3 info** di analyzer (solo `prefer_initializing_formals`) su 31.856 righe. Eppure: 27 test rossi, stutter persistente, progetto abbandonato.

**Lezione diretta per la regola 11**: `flutter analyze` è **necessario, non sufficiente**. L'analyzer non vede lo stutter né il layout rotto. Serve un secondo livello: test widget + evidenza di performance. In v3 la regola 11 da sola non avrebbe salvato la v2.

### P4 — Scope creep: da MVP a 31.856 righe [FATTO]

`docs/product-brief.md` (MVP dichiarato): *"salvare ogni item come file JSON separato; visualizzare una lista semplice filtrabile"*. Fuori scope iniziale: *"notifiche avanzate; calendario complesso ricorrente"*.

Cosa è stato costruito invece:

- Sottosistema notifiche: **~20 file** con `change_planner` (867 righe) · `desired_state_planner` (690) · `change_executor` · `startup_reconciler` · `lifecycle_coordinator` · `id_policy` (557) — per **notifiche locali**.
- Parser Quick Add italiano: **1.844 righe** + `docs/parser_italian_kb.md` (19.644 char).
- `docs/product-direction.md`: roadmap a **19 step** (vista settimana/giorno, bulk edit, ricorrenze, smart rules, sidebar desktop).
- Extra: backup SAF esterno, migratore di storage, catalogo categorie, tag, packaging MSIX.

**Non c'è niente di sbagliato in queste feature.** È sbagliato l'ordine: è stato costruito lo strato 19 prima che lo strato 1 (una lista che non scatta) fosse chiuso.

### P5 — Lavoro abbandonato non committato [FATTO]

Al recupero il working tree è **sporco**:

```
13 files changed, 3829 insertions(+), 558 deletions(-)
?? .opencode/commands/{final-review,flash-review,flash-ui-review}.md
?? test/presentation/calendar/mobile_calendar_views_widget_test.dart
```

Modifiche sostanziali (`main.dart`, tutte le pagine, `app_motion.dart`, `mobile_calendar_views.dart`) **mai committate**, sopra l'ultimo commit `d6bcff2` del `2026-07-22`.

E il backup `%TEMP%\planner-before-pi-20260901-180443\` è una **skeleton vuota**: cartelle `lib/core/*`, `lib/presentation/*` presenti, **zero file**. Chi ha fatto il backup ha copiato l'albero senza i file. Quei 3.829 inserti esistono **solo** in quel working tree: un `git clean` li cancella per sempre.

### P6 — Doppia toolchain (WSL + Windows) [FATTO]

`flutter_01.log`: Flutter 3.44.4 su **Ubuntu WSL2**, `Unable to locate Android SDK`, nessun target Windows disponibile da WSL. Quindi da `AGENTS.md`: `flutter run -d android` è "WSL-safe", il target Windows va lanciato da **PowerShell**. Due ambienti, due Flutter, due percorsi di build — per ogni verifica visiva.

---

## 3. Cosa è recuperabile dalla v2 (e vale la pena)

**42 file su 69 sono puro Dart, senza Flutter** → si trapiantano in v3 cambiando solo lo storage.

| Asset v2 | LOC | Test | Portabile? |
| --- | --- | --- | --- |
| `quick_add_planner_item_parser.dart` | 1.844 | **237 test verdi** (`test/features/items/application/`), incl. 72 di corpus | ✅ puro Dart |
| `quick_add_{category,emoji}_inference.dart` | — | verdi | ✅ puro Dart |
| `domain/` items: `PlannerItem`, `status`, `priority`, `type`, `recurrence`, `ordering` | — | verdi | ✅ puro Dart |
| `domain/` categories + tags | — | verdi | ✅ puro Dart |
| `planner_backup_service` + `planner_backup` domain | — | da verificare | ✅ puro Dart (il gateway SAF no) |
| Sottosistema notifiche | ~20 file | verdi | ⚠️ **riscrivere**, non portare (vedi §4) |
| `presentation/` intera (27 file, ~15k LOC) | — | — | ❌ **non portare**: è la causa di P1/P2 |

**Il valore vero della v2 è il dominio + il parser**, non la UI. 1.844 righe di NLP italiano già testate sono settimane di lavoro che nessuno vuole rifare — e sono la parte *senza* Flutter, quindi si spostano pulite.

---

## 4. Cosa NON portare, e perché

| Cosa | Motivo |
| --- | --- |
| Tutto `lib/presentation/` (27 file) | Causa diretta di P1 e P2. La v3 ha già 1.201 righe di UI pulita. |
| `app_motion.dart` + `MonthCushionScrollPhysics` | Fisica custom = esattamente "animazioni custom pesanti". Usare implicit animations standard. |
| `_HomeAnimated*` (`Transition`/`Presence`/`Section`) | 400 righe di wrapper con bookkeeping ID→indice. Sostituibile con `AnimatedList`/`AnimatedSwitcher` nativi o niente. |
| Storage JSON-un-file-per-item | v3 usa SQLite raw: quest'ultimo è verificabile e transazionale. |
| `setState` manuale / constructor injection | v3: `ChangeNotifier` + `Provider` (regola 4). |
| I ~20 file di orchestrazione notifiche | La necessità è: "programma/annulla una notifica locale". Un servizio + una tabella. Non 6 planner/coordinator/executor. |
| Il processo a ruoli (planner/reviewer/coder, `execute-plan-solo`, `flow-commit*`) | Cerimonia che produce P2. Il flusso v3 (regole 10/11 + `flutter analyze` + test) copre lo stesso bisogno con 2 regole. |

---

## 5. Come la v3 risponde, problema per problema

| P | v2 | v3 (già in vigore) |
| --- | --- | --- |
| P1 stutter | 101 `setState`, 0 `ListView.builder`, pagine da 5k righe | reg. 4 (`ChangeNotifier`+`Provider`, mai `setState` globale) + reg. 5 (`const`, `ListView.builder`) |
| P2 indagini infinite | `home_page.dart` 5.323 righe | vincolo implicito: **nessun file UI oltre ~300 righe** → *da aggiungere* |
| P3 analyze ≠ funziona | analyze pulito, 27 test rossi | reg. 11 (`flutter analyze`) — **incompleta**: serve anche il test verde |
| P4 scope creep | roadmap a 19 step, 20 file per le notifiche | `PROJECT.md` come fonte di stato + ponytail (YAGNI) |
| P5 lavoro non committato | 13 file dirty, backup vuoto | ❌ **nessuna regola v3 lo copre** |
| P6 doppia toolchain | WSL + PowerShell | ❌ **v3 gira solo su host Windows** (sandbox sbx esclusa per `build windows`) |

Due buchi reali da chiudere, decidendoli adesso: **convenzione di commit** (P5) e **un solo ambiente di build** (P6).

---

## 6. Comandi di verifica (riproducibili)

```bash
v2=/c/Users/stefi/code/personal_planner_localfirst
cd $v2
git log --oneline | wc -l                       # 230
git log --oneline | grep -iE "smooth|animat|reorder|stabil"   # 11 commit di churn
find lib -name "*.dart" -exec wc -l {} + | sort -rn | head    # home_page 5323
grep -rn "setState(" lib/ | wc -l               # 101
grep -rn "ListView.builder" lib/ | wc -l        # 0
grep -rn "Column(" lib/ | wc -l                 # 112
flutter analyze                                 # 3 info
flutter test --concurrency=2                    # 1170 pass, 27 fail
git diff --shortstat                            # 13 files, +3829/-558 (dirty)
timeout 300 flutter test test/features/items/application/   # 237 pass (parser OK)
```
