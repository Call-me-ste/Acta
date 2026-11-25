import 'package:flutter/material.dart';

import '../shared/motion.dart';
import '../shared/picker_tile.dart';
import '../../core/reminders/reminder_leads.dart';
import '../../theme/design_tokens.dart';
import 'item_sound_sheet.dart';

/// Il risultato del foglio promemoria: `leads` null = predefinito,
/// elenco vuoto = nessun promemoria, altrimenti i minuti di anticipo.
class ReminderChoice {
  const ReminderChoice(this.leads, this.sound);

  final List<int>? leads;
  final bool? sound;
}

/// «15 minuti», «1 ora», «1 ora e 30 minuti», «1 giorno».
String leadPhrase(int minutes) {
  if (minutes <= 0) return "all'ora esatta";
  if (minutes < 60) {
    return '$minutes ${minutes == 1 ? 'minuto' : 'minuti'}';
  }
  if (minutes < 1440) {
    final ore = minutes ~/ 60;
    final resto = minutes % 60;
    final testo = '$ore ${ore == 1 ? 'ora' : 'ore'}';
    return resto == 0 ? testo : '$testo e $resto minuti';
  }
  final giorni = minutes ~/ 1440;
  return '$giorni ${giorni == 1 ? 'giorno' : 'giorni'}';
}

/// La riga del form dice **cosa succede**, non «Come impostazioni».
///
/// Il valore resta **corto** (`15 min prima`, non `15 minuti prima`): la riga
/// sta accanto all'etichetta e alla freccia, e con le parole lunghe andava a
/// capo mentre «Ripetizione» restava su una riga sola. Il foglio, dove c'è
/// spazio, usa ancora la frase intera.
String reminderSummary(List<int>? leads, int defaultMinutes) {
  if (leads == null) {
    return defaultMinutes <= 0
        ? "All'ora esatta"
        : '${leadLabel(defaultMinutes)} prima';
  }
  if (leads.isEmpty) return 'Nessun promemoria';
  if (leads.length == 1 && leads.single == 0) return "All'ora esatta";
  return '${leads.map(leadLabel).join(' e ')} prima';
}

/// Il foglio del promemoria: predefinito, nessuno, oppure gli anticipi scelti.
Future<ReminderChoice?> scegliPromemoria(
  BuildContext context, {
  required List<int>? leads,
  required int defaultMinutes,
  required bool? sound,
  required String defaultSound,
  String? fixedReminderTime,
}) {
  return showActaSheet<ReminderChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (_) => _ReminderSheet(
      leads: leads,
      defaultMinutes: defaultMinutes,
      sound: sound,
      defaultSound: defaultSound,
      fixedReminderTime: fixedReminderTime,
    ),
  );
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({
    required this.leads,
    required this.defaultMinutes,
    required this.sound,
    required this.defaultSound,
    this.fixedReminderTime,
  });

  final List<int>? leads;
  final int defaultMinutes;
  final bool? sound;
  final String defaultSound;
  final String? fixedReminderTime;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late List<int>? _leads = widget.leads;
  late bool? _sound = widget.sound;

  bool get _predefinito =>
      _leads == null ||
      (widget.fixedReminderTime != null && _leads!.isNotEmpty);

  List<int> get _scelti => _leads ?? const [];

  void _toggle(int minuti, bool acceso) {
    final prossimi = {..._scelti};
    if (acceso) {
      prossimi.add(minuti);
    } else {
      prossimi.remove(minuti);
    }
    setState(() => _leads = (prossimi.toList()..sort()));
  }

  Future<void> _aggiungiPersonalizzato() async {
    final minuti = TextEditingController();
    final scelto = await showActaDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Minuti prima'),
        content: TextField(
          key: const ValueKey('anticipo-personalizzato'),
          controller: minuti,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            helperText: 'Da 1 a 10080 (una settimana)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final valore = int.tryParse(minuti.text.trim());
              if (valore == null ||
                  valore < 1 ||
                  valore > maxReminderLeadMinutes) {
                return;
              }
              Navigator.pop(ctx, valore);
            },
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
    if (scelto == null || !mounted) return;
    setState(() => _leads = ({..._scelti, scelto}.toList()..sort()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tutti = {...standardLeads, ..._scelti}.toList()..sort();

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Promemoria', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.s),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Predefinito'),
                subtitle: Text(
                  widget.fixedReminderTime ??
                      (widget.defaultMinutes <= 0
                          ? "All'ora esatta"
                          : '${leadPhrase(widget.defaultMinutes)} prima'),
                ),
                trailing: _predefinito
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : null,
                onTap: () => setState(() => _leads = null),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nessun promemoria'),
                trailing: _leads != null && _leads!.isEmpty
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : null,
                onTap: () => setState(() => _leads = const []),
              ),
              const Divider(height: AppSpacing.xl),
              if (widget.fixedReminderTime == null)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: _scelti.isNotEmpty,
                  title: const Text('Personalizza'),
                  subtitle: _scelti.isEmpty
                      ? null
                      : Text(reminderSummary(_leads, widget.defaultMinutes)),
                  children: [
                    for (final minuti in tutti)
                      CheckboxListTile(
                        key: ValueKey('anticipo-$minuti'),
                        contentPadding: EdgeInsets.zero,
                        value: _scelti.contains(minuti),
                        onChanged: (on) => _toggle(minuti, on ?? false),
                        title: Text(minuti == 0
                            ? "All'ora esatta"
                            : '${leadPhrase(minuti)} prima'),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.add),
                      title: const Text('Minuti personalizzati…'),
                      onTap: _aggiungiPersonalizzato,
                    ),
                  ],
                ),
              PickerTile(
                icon: Icons.volume_up_outlined,
                label: 'Suono',
                value: soundSummary(_sound, widget.defaultSound),
                onTap: () async {
                  final choice = await scegliSuono(context,
                      sound: _sound, defaultSound: widget.defaultSound);
                  if (choice != null && mounted) {
                    setState(() => _sound = choice.sound);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.s),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, ReminderChoice(_leads, _sound)),
                child: const Text('Fatto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
