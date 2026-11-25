import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'view_push_switcher_view.dart';

/// Fa scorrere pagine opache mantenendone lo stato e la posizione di scroll.
/// Un solo orologio muove tutte le pagine. Un nuovo tocco parte dalle posizioni
/// già disegnate e cambia destinazione senza accodare un secondo movimento.
class ViewPushSwitcher extends StatefulWidget {
  const ViewPushSwitcher({
    super.key,
    required this.index,
    required this.children,
    this.animate = true,
    this.warmUp = true,
  });

  final int index;
  final List<Widget> children;
  final bool animate;
  final bool warmUp;

  static const double parallax = 0.35;

  @override
  State<ViewPushSwitcher> createState() => _ViewPushSwitcherState();
}

typedef _Travel = ({double from, double to});

class _ViewPushSwitcherState extends State<ViewPushSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  late final _mountedViews = {widget.index};
  late List<int> _scene = [widget.index];
  Map<int, _Travel> _travel = const {};
  Curve _curve = AppMotion.viewCurve;
  int? _warming;
  bool _warmScheduled = false;
  bool _startScheduled = false;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this)
      ..addStatusListener(_motionChanged);
    _scheduleWarmUp();
  }

  void _scheduleWarmUp() {
    if (!widget.animate ||
        !widget.warmUp ||
        _warmScheduled ||
        _warming != null ||
        _mountedViews.length >= widget.children.length) {
      return;
    }
    _warmScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmScheduled = false;
      if (!mounted || !widget.animate || _travel.isNotEmpty) return;
      final index = Iterable<int>.generate(widget.children.length).firstWhere(
          (index) => !_mountedViews.contains(index),
          orElse: () => -1);
      if (index < 0) return;
      setState(() {
        _warming = index;
        _mountedViews.add(index);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _warming != index) return;
        setState(() => _warming = null);
        _scheduleWarmUp();
      });
    });
  }

  @override
  void didUpdateWidget(covariant ViewPushSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.index;
    _mountedViews.add(next);
    if (!widget.animate) {
      _clock.stop();
      _showOnlyTarget();
      return;
    }
    if (oldWidget.index == next) {
      _scheduleWarmUp();
      return;
    }

    final wasMoving = _travel.isNotEmpty;
    final position = {
      for (final index in _scene) index: _position(index),
    };
    final direction = next > oldWidget.index ? 1.0 : -1.0;
    _clock.stop();
    _warming = null;
    final layer = _scene.indexOf(next);
    if (layer == -1) {
      // La pagina nuova entra davanti, partendo dal bordo. Le precedenti
      // avanzano insieme e continuano a coprire il resto dello schermo.
      _travel = {
        for (final entry in position.entries)
          entry.key: (
            from: entry.value,
            to: entry.value - direction * ViewPushSwitcher.parallax,
          ),
        next: (from: direction, to: 0),
      };
      _scene = [..._scene, next];
    } else {
      // Mantiene sia l'ordine di pittura sia l'ordine orizzontale dei bordi.
      // Ogni coppia di bordi contigui che si toccava resta in contatto mentre
      // la destinazione va a zero e le altre pagine si spostano ai lati.
      final target = position[next]!;
      _travel = {
        for (final entry in position.entries)
          entry.key: (
            from: entry.value,
            to: entry.key == next
                ? 0
                : entry.value == target
                    ? -direction
                    : (entry.value - target).sign,
          ),
      };
    }
    _curve = wasMoving ? AppMotion.viewRetargetCurve : AppMotion.viewCurve;
    _clock.duration = wasMoving ? AppMotion.viewRetarget : AppMotion.viewSwitch;
    _clock.value = 0;

    // Il primo layout di una pagina appena visitata precede il movimento.
    if (_startScheduled) return;
    _startScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScheduled = false;
      if (mounted && widget.animate && _travel.isNotEmpty) _clock.forward();
    });
  }

  double _position(int index) {
    final travel = _travel[index];
    if (travel == null) {
      return index == _scene.last || index == _warming
          ? 0
          : (index < widget.index ? -1 : 1);
    }
    return lerpDouble(travel.from, travel.to, _curve.transform(_clock.value))!;
  }

  void _motionChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(_showOnlyTarget);
    _scheduleWarmUp();
  }

  void _showOnlyTarget() {
    _scene = [widget.index];
    _travel = const {};
    _warming = null;
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paintOrder = [
      for (final index in _mountedViews)
        if (!_scene.contains(index) && index != _warming) index,
      if (_warming case final index?) index,
      ..._scene,
    ];
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final index in paintOrder)
            VistaSpostata(
              key: ValueKey('vista-$index'),
              indice: index,
              clock: _travel.containsKey(index) ? _clock : null,
              position: () => _position(index),
              inScena: index == _warming || _scene.contains(index),
              attiva: index == widget.index,
              child: widget.children[index],
            ),
        ],
      ),
    );
  }
}
