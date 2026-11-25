import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/database/settings_store.dart';
import 'domain/reminder_plan.dart';

/// Preferenze delle notifiche, salvate per dispositivo.
class NotificationSettingsController extends ChangeNotifier {
  NotificationSettingsController(this._store);

  final SettingsStore _store;

  /// L'interruttore generale: **spento di partenza**. Un'app che comincia a
  /// mandare avvisi appena installata, senza che nessuno l'abbia chiesto, è
  /// esattamente il motivo per cui la gente spegne le notifiche in blocco.
  /// Accendendolo si chiede il permesso (Android 13+), e da lì in poi si vede
  /// cosa arriva.
  static const String notificheAttiveKey = 'notificheAttive';
  static const String eventoKey = 'notificaEvento';
  static const String todoKey = 'notificaTodo';
  static const String tuttoIlGiornoKey = 'notificaTuttoIlGiorno';
  static const String riepilogoKey = 'notificaRiepilogo';
  static const String silenzioDaKey = 'notificaSilenzioDa';
  static const String silenzioAKey = 'notificaSilenzioA';
  static const String anticipoEventiKey = 'notificaAnticipoEventi';
  static const String anticipoTodoKey = 'notificaAnticipoTodo';
  static const String oraTodoKey = 'notificaOraTodo';
  static const String oraTuttoIlGiornoKey = 'notificaOraTuttoIlGiorno';
  static const String oraRiepilogoKey = 'notificaOraRiepilogo';
  static const String suonoKey = 'notificaSuono';
  static const String vibraEventiKey = 'notificaVibraEventi';
  static const String vibraTodoKey = 'notificaVibraTodo';
  static const String bloccoKey = 'notificaBlocco';

  /// I suoni che si possono scegliere.
  ///
  /// **Non** sono tre file audio nostri: sono i tre suoni che il telefono ha
  /// **già** (la notifica di sistema, la sveglia, la suoneria), presi per
  /// indirizzo `content://`. Così non si aggiunge al repo nessun file da
  /// licenziare, e chi ha cambiato le suonerie del telefono se le trova qui
  /// dentro. Se un giorno si vogliono tre suonate nostre, sono tre file in
  /// `res/raw/` e tre righe in `notification_channels.dart`.
  static const String suonoSistema = 'sistema';
  static const String suonoSveglia = 'sveglia';
  static const String suonoSuoneria = 'suoneria';
  static const String suonoNessuno = 'nessuno';

  /// Tutti i suoni ammessi, nell'ordine in cui si vedono.
  static const List<String> suoni = [
    suonoSistema,
    suonoSveglia,
    suonoSuoneria,
    suonoNessuno,
  ];

  /// Cosa si legge sulla schermata di blocco (`NotificationVisibility` di
  /// Android: pubblico = tutto, privato = nascosto sui blocchi protetti,
  /// segreto = nascosto del tutto).
  static const String bloccoPubblico = 'pubblico';
  static const String bloccoPrivato = 'privato';
  static const String bloccoSegreto = 'segreto';

  /// Le ore silenziose di default: 22:00 → 07:00.
  static const int silenzioDaDefault = 22 * 60;
  static const int silenzioADefault = 7 * 60;

  static const int anticipoEventiDefault = 15;
  static const int anticipoTodoDefault = 0;
  static const int oraTodoDefault = 9 * 60;
  static const int oraTuttoIlGiornoDefault = 8 * 60;
  static const int oraRiepilogoDefault = 20 * 60;

  bool _attive = false;
  bool _evento = true;
  bool _todo = true;
  bool _tuttoIlGiorno = true;
  bool _riepilogo = false;
  int _silenzioDa = silenzioDaDefault;
  int _silenzioA = silenzioADefault;
  int _anticipoEventi = anticipoEventiDefault;
  int _anticipoTodo = anticipoTodoDefault;
  int _oraTodo = oraTodoDefault;
  int _oraTuttoIlGiorno = oraTuttoIlGiornoDefault;
  int _oraRiepilogo = oraRiepilogoDefault;
  String _suono = suonoSistema;
  bool _vibraEventi = true;
  bool _vibraTodo = true;
  String _blocco = bloccoPrivato;

  bool get attive => _attive;
  bool get evento => _evento;
  bool get todo => _todo;
  bool get tuttoIlGiorno => _tuttoIlGiorno;
  bool get riepilogo => _riepilogo;
  int get silenzioDa => _silenzioDa;
  int get silenzioA => _silenzioA;
  int get anticipoEventi => _anticipoEventi;
  int get anticipoTodo => _anticipoTodo;
  int get oraTodo => _oraTodo;
  int get oraTuttoIlGiorno => _oraTuttoIlGiorno;
  int get oraRiepilogo => _oraRiepilogo;
  String get suono => _suono;
  bool get vibraEventi => _vibraEventi;
  bool get vibraTodo => _vibraTodo;
  String get blocco => _blocco;

  /// Le ore silenziose come le vuole il pianificatore, o `null` quando sono
  /// spente (inizio = fine): un `QuietHours` con gli estremi uguali sarebbe un
  /// intervallo che non esiste, ed è più chiaro dirlo qui che in tre punti.
  QuietHours? get quietHours =>
      _silenzioDa == _silenzioA ? null : (start: _silenzioDa, end: _silenzioA);

  /// Se l'avviso di quel tipo deve **suonare**: spento solo quando il tono
  /// scelto è «nessuno». È il default del pianificatore per gli elementi che
  /// non dicono niente di loro.
  bool get suona => _suono != suonoNessuno;

  /// Se un tipo di avviso è acceso **davvero** (generale + tipo).
  bool get eventoAttivo => _attive && _evento;
  bool get todoAttivo => _attive && _todo;
  bool get tuttoIlGiornoAttivo => _attive && _tuttoIlGiorno;
  bool get riepilogoAttivo => _attive && _riepilogo;

  /// Legge tutte le preferenze in una volta: sono sedici e servono insieme (al
  /// pianificatore e alla sezione), quindi leggerle una per una sarebbe solo
  /// più lento.
  void load() {
    final valori = _store.all();

    _attive = valori[notificheAttiveKey] == '1';
    _evento = valori[eventoKey] != '0';
    _todo = valori[todoKey] != '0';
    _tuttoIlGiorno = valori[tuttoIlGiornoKey] != '0';
    // Prima il riepilogo era attivo anche in assenza di una scelta esplicita.
    _riepilogo = (valori[riepilogoKey] ??
            (valori.containsKey(notificheAttiveKey) ? '1' : '0')) ==
        '1';

    _silenzioDa =
        _minuti(valori[silenzioDaKey], silenzioDaDefault, 0, 24 * 60 - 1);
    _silenzioA =
        _minuti(valori[silenzioAKey], silenzioADefault, 0, 24 * 60 - 1);

    _anticipoEventi = _minuti(
        valori[anticipoEventiKey], anticipoEventiDefault, 0, 7 * 24 * 60);
    _anticipoTodo =
        _minuti(valori[anticipoTodoKey], anticipoTodoDefault, 0, 7 * 24 * 60);

    _oraTodo = _minuti(valori[oraTodoKey], oraTodoDefault, 0, 24 * 60 - 1);
    _oraTuttoIlGiorno = _minuti(
        valori[oraTuttoIlGiornoKey], oraTuttoIlGiornoDefault, 0, 24 * 60 - 1);
    _oraRiepilogo =
        _minuti(valori[oraRiepilogoKey], oraRiepilogoDefault, 0, 24 * 60 - 1);

    _suono = _unoTra(valori[suonoKey], suoni, suonoSistema);
    _vibraEventi = valori[vibraEventiKey] != '0';
    _vibraTodo = valori[vibraTodoKey] != '0';
    _blocco = _unoTra(
      valori[bloccoKey],
      const [bloccoPubblico, bloccoPrivato, bloccoSegreto],
      bloccoPrivato,
    );

    notifyListeners();
  }

  void setAttive(bool valore) {
    if (valore == _attive) return;
    _attive = valore;
    final riepilogo = _riepilogo;
    scheduleMicrotask(() {
      if (_store.get(riepilogoKey) == null) {
        _store.set(riepilogoKey, riepilogo ? '1' : '0');
      }
    });
    _scrivi(notificheAttiveKey, valore ? '1' : '0');
  }

  void setEvento(bool valore) {
    if (valore == _evento) return;
    _evento = valore;
    _scrivi(eventoKey, valore ? '1' : '0');
  }

  void setTodo(bool valore) {
    if (valore == _todo) return;
    _todo = valore;
    _scrivi(todoKey, valore ? '1' : '0');
  }

  void setTuttoIlGiorno(bool valore) {
    if (valore == _tuttoIlGiorno) return;
    _tuttoIlGiorno = valore;
    _scrivi(tuttoIlGiornoKey, valore ? '1' : '0');
  }

  void setRiepilogo(bool valore) {
    if (valore == _riepilogo) return;
    _riepilogo = valore;
    _scrivi(riepilogoKey, valore ? '1' : '0');
  }

  void setSilenzio({required int da, required int a}) {
    if (da == _silenzioDa && a == _silenzioA) return;
    _silenzioDa = da;
    _silenzioA = a;
    notifyListeners();
    scheduleMicrotask(() {
      _store.set(silenzioDaKey, '$da');
      _store.set(silenzioAKey, '$a');
    });
  }

  void setAnticipoEventi(int minuti) {
    if (minuti == _anticipoEventi) return;
    _anticipoEventi = minuti.clamp(0, 7 * 24 * 60);
    _scrivi(anticipoEventiKey, '$_anticipoEventi');
  }

  void setAnticipoTodo(int minuti) {
    if (minuti == _anticipoTodo) return;
    _anticipoTodo = minuti.clamp(0, 7 * 24 * 60);
    _scrivi(anticipoTodoKey, '$_anticipoTodo');
  }

  void setOraTodo(int minuti) {
    final pulito = minuti.clamp(0, 24 * 60 - 1);
    if (pulito == _oraTodo) return;
    _oraTodo = pulito;
    _scrivi(oraTodoKey, '$pulito');
  }

  void setOraTuttoIlGiorno(int minuti) {
    final pulito = minuti.clamp(0, 24 * 60 - 1);
    if (pulito == _oraTuttoIlGiorno) return;
    _oraTuttoIlGiorno = pulito;
    _scrivi(oraTuttoIlGiornoKey, '$pulito');
  }

  void setOraRiepilogo(int minuti) {
    final pulito = minuti.clamp(0, 24 * 60 - 1);
    if (pulito == _oraRiepilogo) return;
    _oraRiepilogo = pulito;
    _scrivi(oraRiepilogoKey, '$pulito');
  }

  void setSuono(String valore) {
    if (!suoni.contains(valore)) return;
    if (valore == _suono) return;
    _suono = valore;
    _scrivi(suonoKey, valore);
  }

  void setVibraEventi(bool valore) {
    if (valore == _vibraEventi) return;
    _vibraEventi = valore;
    _scrivi(vibraEventiKey, valore ? '1' : '0');
  }

  void setVibraTodo(bool valore) {
    if (valore == _vibraTodo) return;
    _vibraTodo = valore;
    _scrivi(vibraTodoKey, valore ? '1' : '0');
  }

  void setBlocco(String valore) {
    if (!const [bloccoPubblico, bloccoPrivato, bloccoSegreto]
        .contains(valore)) {
      return;
    }
    if (valore == _blocco) return;
    _blocco = valore;
    _scrivi(bloccoKey, valore);
  }

  void _scrivi(String chiave, String valore) {
    // Come in `AppSettingsController`: la UI si aggiorna subito, il disco
    // aspetta la fine del fotogramma — dentro il fotogramma del gesto una
    // scrittura SQLite si vede.
    notifyListeners();
    scheduleMicrotask(() => _store.set(chiave, valore));
  }

  static int _minuti(String? grezzo, int ripiego, int min, int max) {
    final letto = int.tryParse(grezzo ?? '');
    return (letto ?? ripiego).clamp(min, max);
  }

  static String _unoTra(String? grezzo, List<String> ammessi, String ripiego) =>
      ammessi.contains(grezzo) ? grezzo! : ripiego;
}
