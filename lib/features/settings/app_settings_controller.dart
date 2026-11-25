import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/database/settings_store.dart';
import '../palette/domain/presets.dart';
import 'priority_colors.dart';

/// La vista scelta per il calendario.
enum CalendarView { mese, settimana, giorno }

/// Come si vedono i **todo dentro il calendario**.
///
/// - `compatta`: in fondo, in una fascia che si apre (il «pulldown» del mese);
/// - `nascosta`: per niente — restano nella scheda Todo, che è il loro posto;
/// - `pieni`: come righe dentro la giornata, con l'orario nella timeline e senza
///   orario nella corsia delle giornate intere.
///
/// `nascosta` **non** tocca la scheda Todo, il foglio degli scaduti all'avvio né
/// i promemoria: riguarda solo quello che il calendario disegna.
enum TodoInCalendario { compatta, nascosta, pieni }

/// Come si presenta l'app **su questo device**.
///
/// Tutto quello che c'è qui è per-device e non entra nel sync (tema scelto,
/// palette attiva, animazioni, cartella di backup): telefono e PC possono
/// volerne di diversi, e non c'è niente da riconciliare.
///
/// I valori stanno in `app_settings` come stringhe e si convertono qui, con un
/// default esplicito per ognuno: una preferenza assente non deve rompere l'avvio.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController(this._store);

  final SettingsStore _store;

  static const String _themeModeKey = 'themeMode';
  static const String activePaletteKey = 'activePaletteId';
  static const String _animationsKey = 'animationsEnabled';
  static const String _calendarViewKey = 'calendarView';
  static const String _todoInCalendarioKey = 'todoInCalendario';
  static const String _backupFolderKey = 'backupFolder';
  static const String _backupRetentionKey = 'backupRetention';
  static const String _lastBackupKey = 'lastBackupAt';
  static const String _overdueWindowKey = 'overdueWindowDays';
  static const String _firstRunKey = 'firstRunDone';
  static const String _priorityColorsKey = 'priorityColors';
  static const String _advancedModeKey = 'advancedMode';

  /// Con che build sono stati scritti i dati che ci sono adesso: `test` o
  /// `ufficiale`. La scrive `BackupController` (non e' una scelta dell'utente),
  /// e serve a **una** cosa: accorgersi che i dati vengono da un'altra build e
  /// fare la copia prima di aprirli.
  static const String _buildKindKey = 'buildKind';

  static const String themeSystem = 'system';
  static const String themeLight = 'light';
  static const String themeDark = 'dark';

  static const int defaultBackupRetention = 10;
  static const int defaultOverdueWindowDays = 30;

  String _themeMode = themeSystem;
  String _activePaletteId = defaultPaletteId;
  bool _animationsEnabled = true;
  CalendarView _calendarView = CalendarView.mese;

  /// Il default e' **compatta**: e' quello che il calendario fa da sempre, e
  /// nessuno deve scoprire un'impostazione per non vedere cambiare niente.
  TodoInCalendario _todoInCalendario = TodoInCalendario.compatta;
  String? _backupFolder;
  int _backupRetention = defaultBackupRetention;
  DateTime? _lastBackupAt;
  int _overdueWindowDays = defaultOverdueWindowDays;
  bool _firstRunDone = false;

  /// Vero quando chi usa l'app vuole vedere **anche i comandi**: pesi, percorso,
  /// verifica, compattazione a mano, quante copie tenere. Spento (default) la pagina
  /// delle copie mostra solo quello che serve a chi ha paura di perdere i dati.
  bool _advancedMode = false;

  /// `null` = chiave mai scritta, cioe' installazione nuova (nessuna copia da
  /// fare: non c'e' niente di scritto da un'altra build).
  String? _buildKind;

  /// I colori delle quattro priorita', nell'ordine del codice (Bassa, Media,
  /// Alta, Urgente). Stanno qui e non nel tema: cambiando palette, "urgente e'
  /// rosso" deve restare vero.
  List<String> _priorityColors = List<String>.of(defaultPriorityColors);

  String get themeMode => _themeMode;
  String get activePaletteId => _activePaletteId;
  bool get animationsEnabled => _animationsEnabled;
  CalendarView get calendarView => _calendarView;
  TodoInCalendario get todoInCalendario => _todoInCalendario;
  String? get backupFolder => _backupFolder;
  int get backupRetention => _backupRetention;
  DateTime? get lastBackupAt => _lastBackupAt;
  int get overdueWindowDays => _overdueWindowDays;
  bool get firstRunDone => _firstRunDone;
  bool get advancedMode => _advancedMode;
  String? get buildKind => _buildKind;
  List<String> get priorityColors => _priorityColors;

  /// Il colore di un livello, con l'indice gia' riportato dentro i quattro.
  String priorityColorOf(int priority) =>
      _priorityColors[priority.clamp(0, _priorityColors.length - 1)];

  /// Legge tutte le preferenze in una volta sola: sono poche e servono al primo
  /// frame (tema e vista), quindi leggerle una per una all'avvio sarebbe solo
  /// più lento.
  void load() {
    final values = _store.all();

    final mode = values[_themeModeKey];
    _themeMode =
        (mode == themeLight || mode == themeDark) ? mode! : themeSystem;

    final palette = values[activePaletteKey];
    _activePaletteId =
        (palette == null || palette.isEmpty) ? defaultPaletteId : palette;

    _animationsEnabled = values[_animationsKey] != '0';

    // Un valore noto o il default: un'impostazione scritta da una versione più
    // recente non deve bloccare l'avvio. `.name` è un'estensione, quindi non può
    // stare in un pattern costante di switch: si confronta a runtime.
    _calendarView = _calendarViewOf(values[_calendarViewKey]);
    _todoInCalendario = _enumOf(
      TodoInCalendario.values,
      values[_todoInCalendarioKey],
      TodoInCalendario.compatta,
    );

    final folder = values[_backupFolderKey];
    _backupFolder = (folder == null || folder.isEmpty) ? null : folder;

    _backupRetention = _clampInt(
      values[_backupRetentionKey],
      defaultBackupRetention,
      3,
      50,
    );
    _lastBackupAt = _millisOrNull(values[_lastBackupKey]);
    _overdueWindowDays = _clampInt(
      values[_overdueWindowKey],
      defaultOverdueWindowDays,
      1,
      365,
    );
    _firstRunDone = values[_firstRunKey] == '1';
    _advancedMode = values[_advancedModeKey] == '1';
    // Nessuna normalizzazione apposta: un valore che non conosciamo vale come
    // «diversa», quindi al massimo si fa una copia in piu' — che e' il verso
    // giusto per sbagliare, davanti a dati da salvare.
    _buildKind = values[_buildKindKey];
    _priorityColors = parsePriorityColors(values[_priorityColorsKey]);

    notifyListeners();
  }

  void setThemeMode(String value) {
    if (value != themeLight && value != themeDark && value != themeSystem) {
      return;
    }
    _themeMode = value;
    _write(_themeModeKey, value);
  }

  void setActivePalette(String paletteId) {
    if (paletteId.isEmpty || paletteId == _activePaletteId) return;
    _activePaletteId = paletteId;
    _write(activePaletteKey, paletteId);
  }

  void setAnimationsEnabled(bool enabled) {
    if (enabled == _animationsEnabled) return;
    _animationsEnabled = enabled;
    _write(_animationsKey, enabled ? '1' : '0');
  }

  void setCalendarView(CalendarView view) {
    if (view == _calendarView) return;
    _calendarView = view;
    _write(_calendarViewKey, view.name);
  }

  void setTodoInCalendario(TodoInCalendario modo) {
    if (modo == _todoInCalendario) return;
    _todoInCalendario = modo;
    _write(_todoInCalendarioKey, modo.name);
  }

  void setPriorityColor(int priority, String hex) {
    final index = priority.clamp(0, _priorityColors.length - 1);
    if (_priorityColors[index] == hex) return;
    _priorityColors = List<String>.of(_priorityColors)..[index] = hex;
    _write(_priorityColorsKey, encodePriorityColors(_priorityColors));
  }

  /// Torna ai quattro colori di base: si toglie la chiave, cosi' il default e'
  /// di nuovo "non impostato" e non una copia salvata dei valori di oggi.
  void resetPriorityColors() {
    _priorityColors = List<String>.of(defaultPriorityColors);
    _store.remove(_priorityColorsKey);
    notifyListeners();
  }

  void setBackupFolder(String? folder) {
    _backupFolder = (folder == null || folder.isEmpty) ? null : folder;
    if (_backupFolder == null) {
      _store.remove(_backupFolderKey);
    } else {
      _store.set(_backupFolderKey, _backupFolder!);
    }
    notifyListeners();
  }

  void setBackupRetention(int value) {
    _backupRetention = value.clamp(3, 50);
    _write(_backupRetentionKey, '$_backupRetention');
  }

  void markBackupDone(DateTime when) {
    _lastBackupAt = when;
    _write(_lastBackupKey, '${when.millisecondsSinceEpoch}');
  }

  void setOverdueWindowDays(int value) {
    _overdueWindowDays = value.clamp(1, 365);
    _write(_overdueWindowKey, '$_overdueWindowDays');
  }

  void markFirstRunDone() {
    if (_firstRunDone) return;
    _firstRunDone = true;
    _write(_firstRunKey, '1');
  }

  void setAdvancedMode(bool attivo) {
    if (attivo == _advancedMode) return;
    _advancedMode = attivo;
    _write(_advancedModeKey, attivo ? '1' : '0');
  }

  /// Scrive con che build sono stati toccati i dati **adesso**. La chiama la
  /// copia, dopo che la copia e' riuscita: se fallisse, al prossimo avvio si
  /// riprova invece di dimenticare il cambio.
  void setBuildKind(String kind) {
    if (kind == _buildKind) return;
    _buildKind = kind;
    _write(_buildKindKey, kind);
  }

  void _write(String key, String value) {
    // La UI si aggiorna **subito**, il salvataggio su disco aspetta la fine del
    // fotogramma.
    //
    // Perche': la scelta della vista passa da qui, e una scrittura SQLite dentro
    // il fotogramma che fa partire l'animazione si vede — misurato sul telefono il
    // 2026-09-17: i primi fotogrammi di un cambio costavano 12-20 ms di `build`,
    // contro 1,4-1,9 ms di mediana. Spostando la scrittura fuori dal fotogramma,
    // il gesto non paga il disco.
    notifyListeners();
    // Una microattività, non un callback di fine fotogramma: la prima gira dopo
    // che il fotogramma (costruzione, impaginazione, disegno) ha finito, la
    // seconda avrebbe bisogno di un binding — e i test di questa classe sono
    // prove pure, senza schermo.
    scheduleMicrotask(() => _store.set(key, value));
  }

  static int _clampInt(String? raw, int fallback, int min, int max) {
    final parsed = int.tryParse(raw ?? '');
    return (parsed ?? fallback).clamp(min, max);
  }

  /// Il nome salvato torna enum; tutto ciò che non è un valore noto cade sul
  /// default. Aggiungere un valore non richiede di toccare questo parse — ed è
  /// uno solo, per tutte le preferenze a elenco (`.name` è un'estensione, quindi
  /// non può stare in un pattern costante di switch: si confronta a runtime).
  static CalendarView _calendarViewOf(String? raw) =>
      _enumOf(CalendarView.values, raw, CalendarView.mese);

  static T _enumOf<T extends Enum>(List<T> values, String? raw, T fallback) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }

  static DateTime? _millisOrNull(String? raw) {
    final parsed = int.tryParse(raw ?? '');
    return parsed == null ? null : DateTime.fromMillisecondsSinceEpoch(parsed);
  }
}
