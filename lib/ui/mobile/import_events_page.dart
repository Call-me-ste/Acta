import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/calendar_import/calendar_import_service.dart';
import '../../features/calendar_import/data/plugin_device_calendar_gateway.dart';
import '../../features/calendar_import/domain/calendar_selection.dart';
import '../../features/calendar_import/domain/device_calendar_gateway.dart';
import '../../features/events/event_provider.dart';
import '../../theme/design_tokens.dart';
import 'import_events_choices.dart';
import 'import_events_widgets.dart';

/// Import **una tantum** dal calendario del telefono.
///
/// La pagina chiede il permesso appena si apre, poi mostra i calendari già
/// presenti sul dispositivo (Google, Outlook, iCloud…): non c'è nessun login
/// Google e nessun collegamento permanente. Gli eventi diventano eventi del
/// Planner e non si aggiornano più da soli.
class ImportEventsPage extends StatefulWidget {
  const ImportEventsPage({super.key, this.gateway});

  /// Iniettabile nei test; sul telefono è il plugin di sistema.
  final DeviceCalendarGateway? gateway;

  @override
  State<ImportEventsPage> createState() => _ImportEventsPageState();
}

class _ImportEventsPageState extends State<ImportEventsPage> {
  late final DeviceCalendarGateway _gateway =
      widget.gateway ?? PluginDeviceCalendarGateway();

  CalendarAccess? _access;
  List<DeviceCalendarInfo> _calendars = const [];
  final Set<String> _selected = {};
  ImportPeriod _period = ImportPeriod.next12;

  bool _loading = true;
  bool _loadingEvents = false;
  bool _importing = false;
  String? _error;
  ImportPlan? _plan;
  ImportResult? _result;

  /// Una risposta vecchia non deve sovrascrivere una scelta più recente.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await _gateway.requestAccess();
      if (!mounted) return;
      setState(() => _access = access);
      if (access != CalendarAccess.granted) {
        setState(() => _loading = false);
        return;
      }
      await _loadCalendars();
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _testoErrore(errore);
      });
    }
  }

  Future<void> _loadCalendars() async {
    try {
      final calendars = await _gateway.calendars();
      if (!mounted) return;
      setState(() {
        _calendars = calendars;
        final predefiniti = defaultCalendars(calendars);
        _selected
          ..clear()
          ..addAll(predefiniti.map((calendar) => calendar.id));
        _loading = false;
      });
      await _loadEvents();
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _testoErrore(errore);
      });
    }
  }

  Future<void> _loadEvents() async {
    if (_selected.isEmpty) {
      setState(() {
        _plan = const ImportPlan(drafts: [], sourceCount: 0, duplicates: 0);
        _loadingEvents = false;
      });
      return;
    }

    final generazione = ++_generation;
    setState(() {
      _loadingEvents = true;
      _error = null;
    });
    final (from, to) = _period.range(DateTime.now());
    try {
      final eventi = await _gateway.events(
        calendarIds: _selected,
        from: from,
        to: to,
      );
      if (!mounted || generazione != _generation) return;
      final colori = {
        for (final calendar in _calendars) calendar.id: calendar.colorHex,
      };
      final piano = CalendarImportService(context.read<EventProvider>())
          .plan(eventi, calendarColors: colori);
      setState(() {
        _plan = piano;
        _loadingEvents = false;
      });
    } catch (errore) {
      if (!mounted || generazione != _generation) return;
      setState(() {
        _loadingEvents = false;
        _error = _testoErrore(errore);
      });
    }
  }

  Future<void> _importa() async {
    final piano = _plan;
    if (piano == null || piano.importable == 0 || _importing) return;

    setState(() {
      _importing = true;
      _error = null;
    });
    final service = CalendarImportService(context.read<EventProvider>());
    try {
      final result = await service.import(piano);
      if (!mounted) return;
      setState(() {
        _importing = false;
        _result = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.imported == 1
                ? 'Importato 1 evento'
                : 'Importati ${result.imported} eventi',
          ),
          action: SnackBarAction(
            label: 'Annulla',
            onPressed: () => _annulla(service, result),
          ),
        ),
      );
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = _testoErrore(errore);
      });
    }
  }

  Future<void> _annulla(
    CalendarImportService service,
    ImportResult result,
  ) async {
    await service.undo(result.ids);
    if (!mounted) return;
    setState(() => _result = null);
    await _loadEvents();
  }

  void _toggleCalendar(String id, bool? selected) {
    setState(() {
      _result = null;
      if (selected ?? false) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
    _loadEvents();
  }

  void _toggleAll() {
    setState(() {
      _result = null;
      if (_selected.length == _calendars.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_calendars.map((calendar) => calendar.id));
      }
    });
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importa eventi')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          Text(
            'Dal calendario del telefono. È un’operazione una tantum: gli '
            'eventi restano nel Planner e non si aggiornano più da soli. Le '
            'ricorrenze entrano come singole occorrenze nel periodo scelto.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.l),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading) ..._contenuto(),
        ],
      ),
    );
  }

  List<Widget> _contenuto() {
    final access = _access;
    if (access == null) {
      return [
        ImportMessage(
          _error ?? 'Non è stato possibile leggere il calendario del telefono.',
        ),
      ];
    }
    if (access != CalendarAccess.granted) {
      return [
        ImportAccessNotice(
          access: access,
          onRetry: _init,
          onOpenSettings: _gateway.openSettings,
        ),
      ];
    }

    return [
      if (_error != null) ...[
        ImportMessage(_error!),
        TextButton(onPressed: _loadEvents, child: const Text('Riprova')),
        const SizedBox(height: AppSpacing.s),
      ],
      ImportCalendars(
        calendars: _calendars,
        selected: _selected,
        onToggle: _toggleCalendar,
        onToggleAll: _toggleAll,
      ),
      ImportPeriodPicker(
        period: _period,
        onChanged: (periodo) {
          setState(() {
            _period = periodo;
            _result = null;
          });
          _loadEvents();
        },
      ),
      const SizedBox(height: AppSpacing.l),
      if (_loadingEvents)
        const Center(child: CircularProgressIndicator())
      else if (_plan != null && _result == null)
        ImportPreview(
          plan: _plan!,
          importing: _importing,
          onImport: _importa,
        ),
      if (_result != null) ...[
        ImportSuccess(result: _result!),
        const SizedBox(height: AppSpacing.s),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Fine'),
        ),
      ],
    ];
  }

  static String _testoErrore(Object errore) {
    if (errore is DeviceCalendarException) return errore.message;
    return 'Non è stato possibile completare l’importazione.';
  }
}
